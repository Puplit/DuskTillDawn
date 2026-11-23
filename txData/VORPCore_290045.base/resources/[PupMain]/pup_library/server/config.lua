-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

Secrets = {
    Webhooks = {
        publishing = '', -- publishing log
    },
}

-- the webhook for a log key, or nil when it is not set
function Secrets.Webhook(key)
    local url = Secrets.Webhooks[key]
    if type(url) ~= 'string' or url == '' then return nil end
    return url
end
