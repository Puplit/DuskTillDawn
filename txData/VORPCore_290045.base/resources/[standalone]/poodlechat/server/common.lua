-- Config setting utilities
function IsSet(value)
	return value and value ~= ''
end

-- THE DISCORD BRIDGE NEEDS discord_rest; without it the Discord features stay off
local warned = false

local function discordRestReady()
	if GetResourceState('discord_rest') == 'started' then return true end
	if not warned then
		warned = true
		print('^3[poodlechat]^7 Discord is configured but discord_rest is not running - Discord features stay off. Install https://github.com/kibook/discord_rest and ensure it before poodlechat.')
	end
	return false
end

function IsDiscordSendEnabled()
	return IsSet(ServerConfig.DiscordWebhookId) and IsSet(ServerConfig.DiscordWebhookToken)
		and discordRestReady()
end

function IsDiscordReceiveEnabled()
	return IsSet(ServerConfig.DiscordBotToken) and IsSet(ServerConfig.DiscordChannel)
		and discordRestReady()
end

function IsDiscordReportEnabled()
	return IsSet(ServerConfig.DiscordReportWebhook) and discordRestReady()
end

function IsDiscordEnabled()
	return IsDiscordSendEnabled() or IsDiscordReceiveEnabled() or IsDiscordReportEnabled()
end
