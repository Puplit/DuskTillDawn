# Modifications

Modified by Puppet (Dusk Till Dawn), 2026.

This resource is based on [VORPCORE/vorp_crawfish](https://github.com/VORPCORE/vorp_crawfish), licensed under the GNU General Public License v2.0 (see `LICENSE`). The modifications are released under the same GPL-2.0 licence as the original.

## Changed

- `client/main.lua`: progress bars use pup-ui instead of vorp_progressbar / progressBars (marked with a `-- Modified by Puppet (Dusk Till Dawn), 2026` line)
- `fxmanifest.lua` (version checker off), `README.md`
- `items/items.sql` moved to `sql/install.sql`
