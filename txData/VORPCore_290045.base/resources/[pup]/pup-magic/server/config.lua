-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

MagicSecrets = {
    castWebhook = "", -- Discord webhook for refused spell casts (someone sent a spell they may not cast). "" = console only
}

-- only an https URL is used
if MagicSecrets.castWebhook ~= '' and not MagicSecrets.castWebhook:find('^https://') then
    print(('^3[%s]^7 castWebhook does not start with https://, ignored'):format(GetCurrentResourceName()))
    MagicSecrets.castWebhook = ''
end
