# Modifications

This is not a stock copy of ox_lib.

- **Upstream:** [overextended/ox_lib](https://github.com/overextended/ox_lib), now maintained as [communityox/ox_lib](https://github.com/communityox/ox_lib), licensed under the GNU LGPL-3.0 (see `LICENSE`).
- **RedM build:** this copy is the RedM version linked in `README.md` ([Rexshack-RedM/ox_lib](https://github.com/Rexshack-RedM/ox_lib)), version 3.32.3.
- **Modified UI:** `web/build` is a compiled interface restyled for RDR2. It uses textures that are not in upstream ox_lib (`menu_header_1a.png`, `weathered_paper.png`, `large_weathered_paper.png`, `selection_box_bg_1d.png`, `divider_line.png`, `progress.png` and the other images in `web/build/assets`).
- **Source:** the source code for this modified `web/build` is not included in this repository, and it is not public upstream either: Rexshack-RedM/ox_lib publishes only the compiled build. If you need LGPL corresponding source, replace `web/build` with an official communityox/ox_lib release build (see below).
- **Changed by Puppet (Dusk Till Dawn), 2026:** in the compiled `web/build` JS and CSS the font was changed from "RDR Lino Regular" to IM Fell English, and the webfontfree script was removed from `web/build/index.html`.
- The textures in `web/build/assets` are Red Dead Redemption 2 UI textures, © Rockstar Games.
- **Replacing it:** you may replace `web/build` with the build from an upstream ox_lib release. The Lua side keeps working; only the look changes.

Fonts in `web/build/fonts`: Roboto (SIL OFL 1.1, `OFL-Roboto.txt`) and Roboto Mono (Apache 2.0, `LICENSE-RobotoMono.txt`).
