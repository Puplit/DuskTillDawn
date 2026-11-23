-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

PH = PH or {}
PH.Secrets = {
    webhook = '', -- Discord webhook for played links; only used when Config.DiscordLog = true
}

-- server/actions.lua checks for nil, so "" (log off) becomes nil
if PH.Secrets.webhook == '' then PH.Secrets.webhook = nil end
