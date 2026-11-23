-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

HuntSecrets = {
    hunts = '', -- Discord webhook for "Legendary Hunt Activated"
}

-- only an https URL is used
if HuntSecrets.hunts ~= '' and not HuntSecrets.hunts:match('^https://') then
    print(('^3[%s]^7 hunts webhook is not an https URL: the hunt log is off'):format(GetCurrentResourceName()))
    HuntSecrets.hunts = ''
end
