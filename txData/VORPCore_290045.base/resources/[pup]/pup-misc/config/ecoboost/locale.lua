-- pup-misc/ecoboost | player-facing text (shown as "<title>. <text>" in a VORP tip; %s / %d are filled in by the code)

EcoBoostLocale = {
    expiredTitle   = 'Eco Boost expired',
    expiredText    = 'Your 24 hour boost is over. Activate it again at the pinboard.',
    cooldownTitle  = 'Eco Boost is on cooldown',
    cooldownText   = 'Available again in: %d hours and %d minutes.',                                -- hours, minutes
    resumedTitle   = 'Eco Boost resumed',
    resumedText    = 'Progress: %s / %s. Earn bonus money from mining, hunting and fishing sales.',  -- earned, cap
    activatedTitle = 'Eco Boost activated',
    activatedText  = 'Earn bonus money from mining, hunting and fishing sales. Maximum bonus: %s.',  -- cap
    completedTitle = 'Eco Boost completed',
    completedText  = 'You earned the maximum %s bonus.',                                             -- cap
    bonusTitle     = 'Eco Boost Bonus: +%s',                                                         -- bonus (General.notifyProgress)
    progressText   = 'Progress: %s / %s',                                                            -- earned, cap
}
