# Live Map blip sprites

The admin panel is a web page. A RDR2 blip is a texture inside the game's own
texture dictionary, addressed by a hash — there is no URL a browser can point at,
so the panel cannot draw one directly.

To use the real sprites: cut each one to a **PNG with a transparent background**
and save it here under the exact filename below. The map picks it up on the next
`restart vorp_admin` — no code change. Any layer with no file keeps the built-in
glyph, so you can do these one at a time.

Recommended size **32x32** or **64x64**. They render at 16x16 inside the pin, and
`object-fit: contain` keeps the aspect ratio, so square art looks best.

## Filenames and the sprite each layer uses

| File | Layer | Sprite hash | Set in |
|---|---|---|---|
| `houses.png` | Houses | `-235048253` | pup_realestate `Config.housebliphash` |
| `hideouts.png` | Hideouts | `-392465725` | pup_hideouts client.lua:525 |
| `clans.png` | Gang camps | `1754365229` | pup_camps `Config.blip` |
| `shops.png` | Player shops | `-242384756` | pup_mercantile `Config.playershopsprite` |
| `socshops.png` | Society shops | `249721687` | pup_mercantile `Config.societystoreblip` |
| `ranches.png` | Ranches | `-569968788` | pup_ranchero config.lua:256 |
| `doors.png` | Door locks | none | doors have no in-game blip |

`1475879922` (`blip_shop_store`) is the sprite on the NPC general stores in
pup_mercantile' `normalstores.lua`. Those are not a live-map layer, so it has no file
here — it is listed only so the hash is not mistaken for the player-shop one.

## Getting the PNGs

The sprites live in the game's blip texture dictionary. Open it in OpenIV or
CodeWalker, find the texture by hash, and export it as PNG. Keep the alpha
channel — the pin draws the sprite over a coloured rounded badge, and a white
background box will look wrong against it.

## Colours

The coloured badge behind the sprite comes from `.pm-prop.<layer>` in
`html/panel.css` and stays whatever you have set there. If a real sprite already
carries its own colour and the badge fights it, set that rule's `background` to
`transparent` and drop its `border`.
