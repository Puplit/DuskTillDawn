-- DiscordQueue | player-facing text
-- Shown in the FiveM/RedM connecting screen. {QUEUE_NUM} / {QUEUE_MAX} are filled in by the queue.

Locale = {
    prefix          = '[DiscordQueue]', -- put in front of every queue / rejection message
    connecting      = 'You are being connected [{QUEUE_NUM}/{QUEUE_MAX}]: ', -- default queue text (no ranked role)
    crashPriority   = 'Welcome back - your spot was held [{QUEUE_NUM}/{QUEUE_MAX}]: ', -- queue text after a crash boost
    discordRequired = 'Your Discord was not detected... You are required to have Discord to play on this server...',
    steamRequired   = 'Your Steam was not detected... You are required to have Steam to play on this server...',
    notWhitelisted  = 'You do not have a Discord role whitelisted for this server... You are not whitelisted.',
    alreadyInQueue  = 'You cannot join again since you are already in the queue...',
}
