-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

BirdSecrets = {
    Webhooks = {
        birds = '', -- purchases, sell-backs, trades and refused requests; empty = no log
    },
    webhook = '', -- filled below from Webhooks[Config.Discord.webhookKey]; server/log.lua reads this
}

-- pick the webhook named by Config.Discord.webhookKey (default 'birds') and trim stray spaces
do
    local key = (Config.Discord and Config.Discord.webhookKey) or 'birds'
    local url = BirdSecrets.Webhooks[key]
    if type(url) == 'string' then
        url = url:gsub('^%s+', ''):gsub('%s+$', '')
        if url ~= '' then BirdSecrets.webhook = url end
    end
end
