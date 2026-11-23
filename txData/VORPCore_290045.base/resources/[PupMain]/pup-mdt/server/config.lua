-- pup-mdt | server-only settings: Discord bot and webhooks. Never sent to clients.
-- Blank values switch the matching feature or channel off.

ServerConfig = {}

ServerConfig.DiscordRole = {
    enabled = true,
    botToken = '',
    guildId = '',
    onDutyRoleId = '',
    removeOnDisconnect = true,
    removeAllOnStop = true,
    userAgentUrl = 'https://example.invalid/pup-mdt',
    userAgentVersion = '1.0',
}

ServerConfig.Discord = {
    username = 'MDT',
    thumbnail = '',
    footerIcon = '',
}

-- webhook URL per channel
ServerConfig.Webhooks = {
    mdt = '',
    -- police
    criminals = '', arrest = '', prison = '', fines = '',
    evidence = '', evidence_locker = '',
    lawmen = '', alerts = '', bulletins = '', reports = '', cases = '',
    statements = '', bounties = '', mostwanted = '',
    expungements = '', permissions = '', duty = '',
    audit = '',
    -- firm
    legal_bail = '', legal_appeals = '', legal_defense = '', legal_expunge = '',
    legal_counsel = '', legal_roster = '', legal_ledger = '', legal_notices = '', legal_duty = '',
    legal = '',
}
