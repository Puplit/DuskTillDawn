ServerConfig = {}

-- JOB LOCK ON TEXT CHAT
ServerConfig.JobLock = {
	Enabled = true,

	-- Only these jobs may use chat. Names must match `characters.job` exactly.
	Jobs = {
		-- law
		police     = true,
		marshal    = true,
		-- medical
		doctor     = true,
		pharmacist = true,
		-- the press
		newspaper  = true,
		-- the bench
		lawyer     = true,
		-- undertakers
		rdundertaker = true,
		sdundertaker = true,
		amundertaker = true,
		-- rail
		standardtrain = true,
	},

	-- true = staff bypass the job list on every locked channel
	AllowStaff = true,

	-- WHO COUNTS AS STAFF. Any one of the three is enough.
	Staff = {
		-- vorp_admin permission keys, so a Discord role grants chat with everything else
		Perms  = { 'open_menu' },
		-- the `group` column, used when Discord cannot be reached
		Groups = { admin = true, superadmin = true, moderator = true },
		-- server.cfg aces
		Aces   = { 'group.admin', 'chat.staffChannel' },
	},

	-- Channels the lock applies to. Staff is absent on purpose (see above).
	Channels = {
		Local   = true, -- proximity chat
		Global  = true, -- server-wide
		Action  = true, -- /me
		Whisper = true, -- /w
	},

	-- Shown to a player whose message was refused. '' = refuse silently.
	DenyMessage = 'You cannot use chat.',
	DenyColor   = { 255, 64, 0 },
}

-- ID of a Discord webhook to post with. Leave as '' to disable sending messages to Discord.
ServerConfig.DiscordWebhookId = ''

-- Token for the above Discord webhook. Leave as '' to disable sending messages to Discord.
ServerConfig.DiscordWebhookToken = ''

-- The default name to use on Discord.
ServerConfig.DiscordName = ''

-- The default avatar to use on Discord.
ServerConfig.DiscordAvatar = ''

-- A Discord bot token, used for getting messages and player avatars. Leave as '' to disable.
ServerConfig.DiscordBotToken = ''

-- Discord channel ID to echo messages in-game from. Leave as '' to disable showing Discord messages in-game.
ServerConfig.DiscordChannel = ''

-- Colour for messages from Discord
ServerConfig.DiscordColor = {115, 138, 219}

-- Discord webhook to post player reports to.
ServerConfig.DiscordReportWebhook = ''

-- Colour used for the report message embed on Discord.
ServerConfig.DiscordReportColor = 0xfe7f9c

-- Message sent to players upon successfully submitting a report.
ServerConfig.DiscordReportFeedbackSuccessMessage = 'Your report has been submitted.'

-- Message sent to players if a report fails.
ServerConfig.DiscordReportFeedbackFailureMessage = 'Sorry, something went wrong with your report.'

-- Colour for the above feedback message.
ServerConfig.DiscordReportFeedbackColor = {255, 165, 0}

-- A Steam API key, used for getting avatars from Steam. Leave as '' to disable.
ServerConfig.SteamKey = ''

-- The ace that grants access to the Staff channel
ServerConfig.StaffChannelAce = 'chat.staffChannel'

-- The ace that allows executing commands from Discord
ServerConfig.ExecuteCommandsAce = 'chat.executeCommands'

-- The prefix used in Discord chat to execute a command
ServerConfig.ChatCommandPrefix = '!'

-- Whether to automatically delete chat commands from the Discord channel
ServerConfig.DeleteChatCommands = true

-- Messages from players with this ace will be visible regardless of them being muted
ServerConfig.NoMuteAce = 'chat.noMute'

-- The primary player identifier used by poodlechat
ServerConfig.Identifier = 'license'

-- Maximum length for player nicknames
ServerConfig.MaxNicknameLen = 30

-- Print chat messages to console
ServerConfig.PrintToConsole = true

-- Framework used to fetch character names
-- ServerConfig.Framework = 'VORP'

-- Roles that can appear in front of player names, based on an ace
--   {name = 'Admin', color = {255, 0, 0}, ace = 'chat.admin'}
-- To show this role for all members of group.admin: add_ace group.admin chat.admin allow
ServerConfig.Roles = {
	--{name = 'Admin', ace = 'chat.admin'},
	--{name = 'Moderator', color = {0, 255, 0}, ace = 'chat.moderator'}
}
