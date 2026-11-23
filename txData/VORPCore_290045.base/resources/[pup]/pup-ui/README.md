# pup-ui

The server's shared interface layer in an RDR2 style. Other resources call it through exports for toasts, banners, posters, menus, shops, input forms, prompts, progress bars, a price picker, 3D world labels and a prop placer, and it also runs the posse (crew) service.

## Features

- **Notifications:** toasts, event banners, wanted posters and an honour meter.
- **Menus:** an ink list menu with slider rows (keyboard driven, no mouse focus), a clickable list menu, a radial wheel, a player menu and a perk card deck.
- **Shop and wardrobe:** a shop with categories and a wardrobe panel with one slider row per clothing category, with the ped left visible.
- **Input form:** text, number, select and textarea fields.
- **Full-screen app:** a data-driven dashboard with tabs, stat cards, tables, rank editors and buttons.
- **Prompts:** a bottom prompt pill shared fairly between resources, and a floating key cap pinned to a world point.
- **Progress bar**, **price picker** and **door lock sounds**.
- **3D world labels:** floating pills over world positions, native 3D text, an in-world editor panel and scene labels.
- **Placement mode:** a crosshair-following prop placer for furniture and similar.
- **Posses:** crews of riders that other resources can read, pay and give tasks to.
- **Compatibility:** a drop-in for `vorp_menu` (and `menuapi`, which it replaced) and `vorp_inputs`, drawn with pup-ui's own menus. See [Using vorp_menu / menuapi / vorp_inputs scripts](#using-vorp_menu--menuapi--vorp_inputs-scripts).
- **Push-to-talk:** voice keeps working while a menu has focus.
- **Safety nets:** only one focus panel at a time, panels close on death and on `/hideui`, and a watchdog releases the mouse if the page and Lua disagree about what is open.
- **Theme:** colours and fonts from one config file, with four presets.

## Requirements

- `vorp_core` (posses, HUD hiding, notifications)
- Optional: `fred_hud` (menu side and progress bar position from its `/hud` editor, HUD hiding)
- Optional: internet access for the app map block background, kibook/webmap's rdr3 `map.jpg` loaded from its public GitHub URL (not shipped, as it has no licence; the block is plain dark without it)
- Optional: a voice resource that sets the `pup_ptt_latched` / `pup_radio_talking` player state bags (push-to-talk inside menus)

## Installation

1. Put `pup-ui` in your resources folder.
2. `ensure pup-ui` early in `server.cfg`, before the resources that use it. It may start before `vorp_core`; it waits for the core on its own.
3. No SQL, items or secrets are needed.

`ptt.lua` must stay at the top level of the resource: other resources load it in their manifests as `@pup-ui/ptt.lua`. `html/` must also stay where it is, as other resources load its fonts through `nui://pup-ui/html/...`.

## Commands

| Command | Who | What |
|---|---|---|
| `/pose`, `/posse` | Everyone | Open the posse menu, or accept a pending posse invite |

## Configuration

### config/main.lua

**Config.General**

| Setting | Meaning |
|---|---|
| `debug` | `true` prints every panel open/close and NUI focus change to the client F8 console |

**Config.Progress**

| Setting | Meaning |
|---|---|
| `style` | The progress bar's default look: `'line'` (a big label and a thin white line, no box) or `'ring'` (a round fill like the health and stamina cores, label beside it). With `fred_hud`, each player picks their own under **Progress Bar** in `/hud`. |

**Config.Posse**

| Setting | Meaning |
|---|---|
| `maxSize` | Most members per posse, leader included |
| `commands` | Chat commands that open the posse menu (they also accept a pending invite) |
| `commandLabel` | The command name shown to players in posse hints and invites |
| `inviteRadius` | Metres the invited rider must be within. `nil` = anywhere on the map |
| `debug` | `true` prints posse traces to the server console |

Invites last 60 seconds.

### config/theme.lua (Theme)

The colours and fonts of every pup-ui menu, prompt, toast and panel.

1. **Pick a preset** in `Config.Theme.preset`: `dusk` (ink and gold, the default), `classic` (black and white, like RDR2 Online's menus), `blood` (dark with blood red) or `frontier` (warm brown leather and cream).
2. **Change a colour** by writing it under `colors`. Anything you leave out comes from the preset. Colours are written as hex (`'#C9A24D'`, also `#RGB` and `#RRGGBBAA`) or `'rgb(r, g, b)'` / `'rgba(201, 162, 77, 0.35)'`. A value that is not a colour is ignored, with a warning in the server console.

   | Slot | Used for |
   |---|---|
   | `background` | Panels, menus, prompts |
   | `text` | The main words |
   | `textDim` | Hints, descriptions, prices |
   | `accent` | Highlights, lines, key caps, headers |
   | `selected` | The focused menu row |
   | `danger` | Warnings, red zones, "can't afford" |
   | `good` | Success, money gained, "owned" |
   | `border` | Thin lines around panels and rows |

3. **Change a font** by putting a `.ttf` or `.otf` file in `pup-ui/html/fonts/` and writing its file name under `fonts`: `title` (headings and menu titles) and `body` (everything else). The name must be a plain file name such as `'myfont.ttf'`. Every font in `html/fonts/` is sent to players automatically. A missing file is reported in the server console, and the page then falls back to Georgia.

   Shipped fonts, all free: `oswald.ttf` (Oswald, condensed headings), `imfell.ttf` (IM Fell English, serif body text), both SIL OFL 1.1, and `robotoslab.ttf` (Roboto Slab, slab serif, Apache 2.0). Their licences are next to them in `html/fonts/`. **`oswald.ttf`, `imfell.ttf` and `robotoslab.ttf` must keep their file names**, because other resources load them by name.

4. **Restart pup-ui.** Players see the change straight away.

Example:

```lua
Config.Theme = {
    preset = 'frontier',
    colors = { accent = '#D4AF37', selected = 'rgba(142, 43, 32, 0.9)' },
    fonts  = { title = 'oswald.ttf', body = 'robotoslab.ttf' },
}
```

`Config.ThemePresets` holds the presets themselves. Edit them only to change a preset; to restyle your own server, set `colors` and `fonts` in `Config.Theme` instead.

**Other resources** can read the resolved theme with `exports['pup-ui']:GetTheme()` on the client or the server. It returns `{ preset, colors = { background, text, textDim, accent, selected, danger, good, border }, fonts = { title, body } }`.

## For developers

All exports are called as `exports['pup-ui']:Name(...)`. Panels that take mouse focus (shop, wardrobe, list, player menu, deck, wheel, input, app) replace each other: opening one force-closes the previous one, which then fires its closed event. Most menus take an `owner` string that is echoed back on their events, so filter on it.

### Notifications (client)

| Export | Data |
|---|---|
| `Toast(data)` | A string, or `{ title, subtitle, symbol, tone, duration }`. `tone` is `'gold'` (default) or `'red'` |
| `Banner(data)` | Event banner table |
| `Poster(data)` | `{ name, crime, reward = '$120.00', duration }` |
| `Honor(data)` | `{ value (0-100), delta, duration }` |
| `Death(data)` / `DeathUpdate(data)` / `DeathHide()` | `{ killerName, killerRole, cause, seconds (countdown), hint }` |
| `DoorSound(kind)` | `'lock'`, `'unlock'` or `'denied'` |

From the server: `TriggerClientEvent('pup-ui:toast', src, data)`, and likewise `pup-ui:banner`, `pup-ui:poster` and `pup-ui:honor`. Use `-1` as `src` for everyone.

### Menus (client)

| Export | Notes |
|---|---|
| `OpenInkMenu(data)` / `HideInkMenu()` | `{ owner, title, subtitle, startIndex, theme, side = 'right', hints = { { keys = {'A','S'}, label = 'Turn' } }, options = { { label, description, image }, { label, values = {0,1,2}, valueIndex = 2, slider = true, noneFirst = true } } }`. Takes no mouse focus. `HideInkMenu` fires no event |
| `OpenListMenu(data)` / `HideListMenu()` | `{ owner, title, subtitle, options = { { label, desc, price, value, disabled } }, keyboard = true, keepInput = true, keepCursor = true, index }`. `keyboard` adds arrow/enter navigation, `keepInput` lets the player keep moving, `keepCursor` keeps the highlighted row on a refresh |
| `OpenWheel(data)` | `{ title, subtitle, items = { { name, label, count, desc } } }` |
| `OpenPlayerMenu(data)` | `{ name, role, roleLabel, gang, rank, xpFrac, honor, heat, cash, bloodMoney, perks = { { id, name, desc, rank, equipped, locked } } }` |
| `OpenPerkDeck(data)` / `UpdatePerkDeck(data)` | Ability card deck |
| `OpenShop(data)` / `HideShop()` | `{ label, cash, rank, items = { { name, label, description, price, category } } }`. The shop stays open for several buys |
| `OpenWardrobe(data)` / `UpdateWardrobe(data)` / `HideWardrobe()` | `{ cats = { { id, label } }, items = { { id, label, cat, count, value, variant, variantCount } } }`. Update with `{ id, value, variant }`. Call `HideWardrobe` after saving |
| `OpenInput(data)` | `{ owner, title, subtitle, submit = 'Confirm', fields = { ... } }`, see below |
| `OpenPricePicker(data)` / `HidePricePicker()` | `{ owner, caption, title, min, max, steps = 12, notch, prefix, foot }`. Left/right moves, Enter confirms, Backspace cancels |
| `OpenApp(data)` / `UpdateApp(data)` / `CloseApp()` | `{ owner, title, subtitle, badge, tabs = { { id, label, icon } or { section = 'AMMO' } }, active, content = { blocks } }`. Block types (heading, stats, glance, table, ranks, actions, list, map and more) are defined in `html/app.js` |
| `IsPanelOpen()` | `true` while a focus panel is open |
| `SetMenuSide(side)` / `GetMenuSide()` | `'left'` or `'right'` for the list, ink and player menus |
| `GetMenuData()` | The vorp_menu-compatible MenuData object (see below) |
| `advancedInput(config)` | The same as `exports.vorp_inputs:advancedInput`: waits and returns the text, or `''` on cancel |

Input form fields: `{ label, type = 'text', placeholder, required, maxlength }`, `{ type = 'number', default, min, max }`, `{ type = 'select', default, options = { { label, value } } }` and `{ type = 'textarea', rows, maxlength }`. The result arrives on `pup-ui:client:inputDone` as `(owner, values)`, where `values` is an array in field order, or `nil` if cancelled.

### Prompts, progress, world (client)

| Export | Notes |
|---|---|
| `Prompt({ key = 'E', label, ttl })` / `PromptHide()` | Keep calling `Prompt` while the player is in range; the pill expires after `ttl` ms (default 800) when nobody refreshes it, and one resource cannot hide another's pill |
| `WorldKey({ x, y, key, text, tone })` / `WorldKeyHide()` | Key cap at screen position `x`, `y` (0-1); you do the world-to-screen |
| `Progress({ label, duration }, onDone)` / `ProgressCancel()` | `duration` in ms (default 5000); `onDone` runs when it fills |
| `Add3DInteraction(id, { coords, text, icon, distance = 6.0, style = 'lock' })` | Floating pill at a world point, shown within `distance` metres. `style = 'lock'` is the iron door plate |
| `Remove3DInteraction(id)` / `Clear3DInteractions()` | |
| `Draw3DText(coords, text, style)` | Native 3D text, call every frame. `style` is optional `{ r, g, b, a, scale }`. Also accepts `(x, y, z, text, style)` |
| `DrawHudPanel({ title, rows, footer, x = 0.15, y = 0.26 })` | Native-text editor panel, call every frame. Rows are `{ label, value, selected }`, `{ text }` or `''` for a spacer |
| `DrawSceneLabels(items)` / `HideSceneLabels()` | One batch per frame, already in screen space: `{ id, x, y, segs = { { t, r, g, b } }, scale, back, a, font }` |
| `StartPlacement({ owner, model, heading, grounded = true, title, bounds = { x, y, z, radius } })` | Ghost prop follows the crosshair. Arrows rotate and raise, Shift+arrows change distance, G toggles ground snap, Enter places, Backspace cancels. Returns `false` if the model fails to load |
| `CancelPlacement()` / `IsPlacing()` | `CancelPlacement` fires no event |

### Client events pup-ui fires (local, `AddEventHandler`)

| Event | Arguments |
|---|---|
| `pup-ui:client:inkMove` / `inkChange` / `inkSelect` / `inkClose` | `(index, owner)` / `(index, valueIndex, owner)` / `(index, valueIndex, owner)` / `(owner)` |
| `pup-ui:client:listSelect` / `listBack` / `listMove` / `listClosed` | `(index, owner)` / `(owner)` / `(index, owner)` / `(owner)` |
| `pup-ui:client:inputDone` / `inputClosed` | `(owner, values)` / none |
| `pup-ui:client:priceChange` / `priceConfirm` / `priceCancel` | `(notch, owner)` / `(notch, owner)` / `(owner)` |
| `pup-ui:client:appNav` / `appAction` / `appClosed` | `(owner, tab)` / `(owner, action, data)` / `(owner)` |
| `pup-ui:client:shopBuy` / `shopClosed` | `(itemName)` / none |
| `pup-ui:client:wardrobeChange` / `wardrobeRotate` / `wardrobeSave` / `wardrobeClosed` | `(data)` / `(dir)` / none / none |
| `pup-ui:client:wheelSelected` / `wheelClosed` | `(item)` / none |
| `pup-ui:client:pmClosed`, `togglePerk`, `deckClosed`, `perkToggle` | `togglePerk` and `perkToggle` pass the perk `id` |
| `pup-ui:client:placeConfirm` / `placeCancel` | `(owner, { x, y, z, heading, grounded })` / `(owner)` |

### Client events pup-ui listens for

| Event | What |
|---|---|
| `pup-ui:HideAllUI` | Panic button: closes every overlay and releases the mouse |
| `pup-ui:menuSide` | `(side)` sets the menu side |
| `pup-ui:progressPos` | `(dx, dy, editing)` moves the progress bar |
| `pup-ui:progressStyle` | `('line' or 'ring')` sets the progress bar's look (also the `SetProgressStyle` export) |
| `menuapi:getData`, `vorp_menu:getData`, `menu_base:getData` | `(cb)` returns the MenuData object (not answered while the real resource of that name is running) |
| `vorpinputs:getInput`, `vorpinputs:getInputsWithInputType`, `vorpinputs:advancedInput` | The vorp_inputs events; `cb` gets the text, or `''` on cancel (not answered while `vorp_inputs` is running) |
| `pup_inputs:sendinputs` | `(confirmLabel, title, cb)` one-field input; `cb` gets the text, or `''` on cancel |

### Using vorp_menu / menuapi / vorp_inputs scripts

pup-ui gives the same MenuData API as [VORPCORE/vorp_menu](https://github.com/VORPCORE/vorp_menu), with the same callback order, so a script written for vorp_menu or menuapi only changes how it gets MenuData:

| The script does | Change |
|---|---|
| `TriggerEvent('vorp_menu:getData', cb)` or `TriggerEvent('menuapi:getData', cb)` | nothing |
| `exports.vorp_menu:GetMenuData()` | `exports['pup-ui']:GetMenuData()` (and `vorp_menu` to `pup-ui` in its fxmanifest dependencies) |
| `TriggerEvent('vorpinputs:getInput', ...)` / `advancedInput` event | nothing |
| `exports.vorp_inputs:advancedInput(cfg)` | `exports['pup-ui']:advancedInput(cfg)` |

What matches vorp_menu:
- `MenuData.Open(type, namespace, name, data, submit, cancel, change, close)`, `Close`, `CloseAll`, `GetOpened`, `GetOpenedMenus`, `IsOpen`, `ReOpen`, `IsInputActive`, and the `Opened` / `LastSelectedIndex` tables.
- On the menu: `close(showRadar, closeSound, triggerCloseEvent)`, `update`, `refresh`, `setElement`, `setElements`, `setTitle`, `setSubtext`, `addNewElement`, `removeElement`, `removeElementByValue`, `removeElementByIndex`, `displayInput`, `isInputActive`.
- Keys: up/down calls `change`; left/right on a slider calls `change` then `submit` (and stops at `min`/`max`); Enter calls `submit` with `data.current` (its `index` set); Back with `data.lastmenu` calls `submit` with `current = 'backup'` and `trigger = lastmenu`, otherwise `cancel` and then the `menuapi:closemenu` / `vorp_menu:closemenu` events.
- `vorp_menu:openmenu` on open (unless `skipOpenEvent`), `vorp_menu:closemenu` on `close()`, the menu sounds, `hideRadar`, the last selected row per menu, and closing and reopening around the pause menu.
- Rows: plain, `slider`, `label-slider`, single `desc-slider`, `text-slider` (`textList`), `tickBox`, `isDisabled`, `desc` / `descText`, `descPrice`, `image`.

Not available: `RegisterControls` (pup-ui's menu takes no keyboard focus; it prints a warning), mouse-only features (`enableCursor`, confirm/cancel buttons, grid layout, multi-slider `desc-slider`), and HTML styling in labels (shown as plain text).

### Posses

Client exports: `OpenPosse()` opens the menu, `GetPosseLocal()` returns the last roster the client received.

Server exports:

| Export | Returns |
|---|---|
| `GetPosse(src)` | `{ inPosse, id, isLeader, members = { { charid, name, src, leader, online } }, count, online, max, command, task, taskLabel, taskOwner }` |
| `GetPosseLocalConfig()` | `{ maxSize, command }` |
| `GetPosseMembers(src)` | Server IDs of every online rider in the player's posse (just `{ src }` when not in one) |
| `IsPosseLeader(src)` | `true` / `false` |
| `SetPosseTask(src, key, label, owner)` | Leader only. `true`, or `false, reason` |
| `GetPosseTask(src)` | `task, taskLabel, taskOwner` |
| `ClearPosseTask(src)` | `true` / `false` |
| `PosseHasTask(src, key)` | `true`, or `false, reason` |

Server event: `pup-ui:posse:serverChanged` fires as `(posseId, onlineSources, task)` on every membership change. A posse's task is cleared whenever a rider joins, leaves or is removed. Offline riders keep their seat (greyed out); a posse ends when all its riders are offline.

### Push-to-talk drop-in

Add `'@pup-ui/ptt.lua'` to another resource's `client_scripts` and its `SetNuiFocus` calls will keep voice working while its page has focus.

## Credits

- These menu textures in `html/img/western/` are Red Dead Redemption 2 UI textures, © Rockstar Games, used for RedM modding: `inkroller_1a`, `menu_header_1a`, `divider_line`, `selection_box_bg_1d`, `selection_box`, `selected-item-box`, `scroller_right_bottom`, `double_border` and `grid`. They are not covered by this resource's licence.
- `cs_bg`, `cs_btn`, `cs_header`, `cs_sep`, `selsected`, `menu_icon_circle` and `tick` (all `.png` in `html/img/western/`) are pup-ui's own art, GPL-3.0 like the rest of the resource. Their SVG sources are in `art-src/western/`. To change one, edit its SVG and render it to a PNG at the same pixel size.
- The door denied sound `html/audio/door_denied.ogg` comes from BOII Development's boii_minigames (GPL-3.0). It is the same file as pup-minigames' `knob.ogg`.
- The door lock and unlock sounds are not shipped here: pup-ui plays pup-minigames' safe crack sounds (`safe_lock_6.mp3` / `safe_lock_5.mp3`, by Fesliyan Studios). Without pup-minigames those two are silent. To use other files, change `DOOR_SOUNDS` in `html/app.js`.

## License

See LICENSE.
