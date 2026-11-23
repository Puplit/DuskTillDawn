-- Server-only settings (Discord webhooks, keys). Loaded only on the server, never sent to players. Leave a webhook "" to turn that log off.

SkinSecrets = {
    skinningLog = "",   -- Discord webhook for the skinning log (also needs Config.SkinningLog.enabled = true)
}

-- strip stray spaces around a pasted URL
SkinSecrets.skinningLog = SkinSecrets.skinningLog:gsub('^%s+', ''):gsub('%s+$', '')
