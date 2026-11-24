ClientConfig = {}

-- Chat commands poodlechat registers. false = not registered, not suggested
ClientConfig.Commands = {
	global         = false,  -- /global /g
	me             = false,  -- /me - pup-scene owns this one
	whisper        = false,  -- /whisper /w  (also kills /reply's only source)
	reply          = false,  -- /reply /r
	staff          = false,  -- /staff
	report         = true,   -- /report
	clear          = true,   -- /clear
	togglechat     = true,   -- /togglechat
	toggleoverhead = true,   -- /toggleoverhead
	mute           = true,   -- /mute /unmute /muted
}

-- Suggestion-list overrides, for commands that live elsewhere or are deliberately unadvertised
ClientConfig.Suggest = {
	report = false,
	say    = false,  -- registered in server/server.lua
	nick   = true,   -- registered in server/server.lua
	emoji  = false,  -- one suggestion per emoji name; ~1600 entries
}

-- Whether to display messages above players' heads by default
ClientConfig.DisplayMessagesAbovePlayersByDefault = false

-- Max distance at which overhead messages are visible.
ClientConfig.OverheadMessageDistance = 50.0

-- Minimum amount of time in milliseconds an overhead message is displayed
ClientConfig.MinOverheadMessageDisplayTime = 5000

-- Maximum amount of time in milliseconds an overhead message is displayed
ClientConfig.MaxOverheadMessageDisplayTime = 10000

-- Number of milliseconds to display an overhead message per character
ClientConfig.OverheadMessageDisplayTimePerChar = 200
