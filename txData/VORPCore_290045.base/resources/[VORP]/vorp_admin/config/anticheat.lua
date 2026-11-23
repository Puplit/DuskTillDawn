-- Modified by Puppet (Dusk Till Dawn), 2026
-- vorp_admin | anti-cheat detectors
-- Movement detectors (teleport, noclip, free cam) run on the client; the cash watcher and the
-- response to a movement flag run on the server. No secrets here: the client needs these.

-------------------------------------------------------------------------------
-- ANTI-CHEAT
-------------------------------------------------------------------------------
Config.AntiCheat = {

	-- Exemption is per capability, not one blanket key. Holding ANY action key in a list
	-- exempts the player from that detector. The list names are the detector names.
	exempt = {
		any      = { 'admin_actions_menu' },  -- never flagged by anything
		teleport = { 'tp_to_waypoint', 'tp_to_coords', 'tp_to_player', 'bring_player', 'tp_player_back' },
		noclip   = { 'noclip' },
		freecam  = { 'noclip', 'spectate' },  -- staff noclip carries the camera off the body
	},

	-- TELEPORT: times a waypoint journey and flags an impossible average speed
	teleport = {
		enabled             = true,
		minDistance         = 350.0, -- metres; shorter hops are ignored
		maxSeconds          = 30.0,  -- only judge arrivals faster than this
		flagSpeedMps        = 40.0,  -- average m/s that counts as impossible
		trackSeconds        = 60.0,  -- give up tracking a waypoint after this
		arriveRadius        = 5.0,   -- metres from the waypoint that count as arrived
	},

	-- CASH WATCHER (server)
	cash = {
		enabled             = true,
		pollSeconds         = 30,     -- how often every player's cash is sampled
		onHandLimit         = 100000, -- cash at or above this is flagged, once per crossing
		jumpAmount          = 25000,  -- cash gained by this much...
		jumpWindowSeconds   = 120,    -- ...inside this many seconds is flagged
		depositFlagAmount   = 50000,  -- bank deposits at or above this are flagged
	},

	-- NOCLIP: moving too fast AND (through geometry OR hovering)
	noclip = {
		enabled             = true,
		tickMs              = 250,  -- check interval
		radius              = 0.40, -- metres, swept sphere used for the geometry test
		footSpeedMps        = 8.0,  -- top honest speed on foot
		horseSpeedMps       = 16.0, -- top honest speed on a horse
		hoverHeight         = 3.0,  -- metres above ground that count as hovering
		hoverMaxVerticalMps = 1.0,  -- vertical speed under this while high = hovering
		strikes             = 4,    -- consecutive bad ticks before reporting
	},

	-- FREE CAM: the camera flies while the ped stays put. A resource with a legitimate long
	-- camera stands this down with
	--     LocalPlayer.state:set('pup_cam_owned', true, false)   -- and false after
	freecam = {
		enabled             = true,
		tickMs              = 500,  -- check interval
		distance            = 80.0, -- metres between the rendered camera and the ped
		holdSeconds         = 8.0,  -- must hold this long, to cover fades and transitions
		maxBodyDrift        = 5.0,  -- metres; the ped moving further than this restarts the clock
		stateBagKey         = 'pup_cam_owned', -- LocalPlayer state key that stands the detector down
	},

	-- RESPONSE to a movement flag (server). Off by default: a flag is logged, not acted on.
	response = {
		kick                = false, -- drop the player after kickAfterFlags flags
		kickAfterFlags      = 3,     -- flags inside one 15 second window
		kickMessage         = 'Movement check failed. Open a ticket if this was a mistake.',
	},
}
