-- pup-medical | player-facing text
-- Pick the language with Config.General.language (config/main.lua). Any key a
-- language leaves out falls back to English. %s / %d are filled in by the code.

Locales = Locales or {}

Locales.en = {
    -- doctors
    medMenuTitle        = 'Doctor\'s Bag',
    medMenuSubtitle     = 'Treat the people around you',
    medOptions          = 'Treatment',
    medOptionsDesc      = 'Revive or bandage someone close by.',
    medRevive           = 'Revive (uses a syringe)',
    medReviveDesc       = 'Bring an unconscious person round.',
    medBandage          = 'Bandage someone',
    medBandageDesc      = 'Dress the wounds of someone close by.',
    reviving            = 'Working on them...',
    bandaging           = 'Dressing the wounds...',
    nobodyNear          = 'There is nobody close enough.',
    notUnconscious      = 'This person is not unconscious.',
    youLack             = 'You have no %s on you.',
    wordSyringe         = 'syringe',
    wordBandage         = 'bandage',
    mustBeOnDuty        = 'You have to be on duty for that.',
    cabinetOpen         = 'Open',
    blipDoctor          = 'Doctor',
    needCertificate     = 'Only a certified doctor may open this.',
    needDuty            = 'Go on duty before you open this.',
    noCharacter         = 'Your character could not be found.',
    cantNow             = 'You can\'t do that right now.',
    bandageDone         = 'The wounds are dressed.',

    -- back-alley syringe
    illegalNobody       = 'There is nobody close enough to inject.',
    illegalNotNeeded    = 'They don\'t need this.',
    injecting           = 'Injecting...',
    illegalSuccess      = 'The back-alley syringe brought them round.',
    illegalFailed       = 'The syringe did nothing. It is spent.',

    -- weakness after a revive
    recoveryStart       = 'You are still weak: no running and no weapons until you recover.',
    recoveryEnd         = 'Your strength is back.',

    -- death
    deathTitle          = 'You Are Down',
    respawnLabel        = 'Respawn',
    hintWaiting         = 'Type /%s to call a doctor, or wait out the timer to respawn',
    hintReady           = 'Hold to respawn, or type /%s to call a doctor',
    hintNoRespawn       = 'Type /%s to call a doctor',
    respawnIn           = 'You can respawn in %d seconds.',
    countdownLabel      = 'Respawn in',

    -- duty
    dutyOn              = 'You are now on duty.',
    dutyOff             = 'You are now off duty.',
    dutyJobNotAllowed   = 'Your job has no duty roster here.',
    dutyWait            = 'Give it a moment before switching again.',
    dutyCheck           = 'Medics on duty: %d (the server console has the details).',
    dutyCheckDenied     = 'You are not allowed to run this check.',
    dutyRestartOff      = 'The server restarts in %d minutes. You have been clocked off duty.',
    dutyRestartNow      = 'The server is about to restart. You have been clocked off duty.',
    dutyRestartLocked   = 'The server restarts soon. You can\'t go on duty now.',

    -- alerts
    noCalls             = 'Nobody is calling for help right now.',
    noMoreCalls         = 'That was the last open call.',
    deadCantUse         = 'You can\'t send this while you are down.',
    searchHint          = 'Check your map for the marked area.',
    callRemoved         = 'The call has been dropped.',
    alertRemoved        = 'You turned the call down.',
    callGone            = 'That call is no longer open.',
    accepted            = 'You took the call. They know you are coming.',
    arrived             = 'You have reached the caller.',
    notOnDuty           = 'You are not on duty.',
    blipAlert           = 'Call for help',
    nobodyOnDuty        = 'Nobody is on duty to help you.',
    noMedicsFree        = 'No medics are on duty. You may respawn without losing anything.',
    cooldown            = 'You can only send this once every %d seconds.',
    cantUseAlert        = 'You are not allowed to send this call.',
    nearStation         = 'You have to be near a station to send this.',
    noAccess            = 'You have no access to these calls.',
    allCleared          = 'All your calls are cleared.',
    upCancelled         = 'You are back on your feet, so your call was withdrawn.',
    busyFinishFirst     = 'Finish the call you are on first.',

    -- on-screen lines
    txtCancel           = 'Type /%s to withdraw your call',
    txtCancelClear      = 'Type /%s to clear this',
    txtSent             = 'Your call has gone out',
    txtComing           = 'Help is on the way',
    txtNoMedics         = 'No medics are on duty',
    txtInWater          = 'You are in the water: a respawn here costs you your belongings',
    txtOnLand           = 'You are on dry land: a respawn here is safe',
    txtNobody           = 'Nobody is on duty to help you',
    txtIncoming         = 'Someone is calling for help',
    txtIncomingHow      = 'Type /alertmenu to see the calls',
    txtResponding       = 'You are answering a call',
    txtRespondingStop   = 'Type /%s to stand down',

    -- call list and decision prompts
    listTitle           = '%s Calls',
    listSubtitle        = '%d open calls',
    listSubtitleCapped  = 'Showing 20 of %d calls',
    rowDead             = 'DOWN',
    rowAlive            = 'AWAKE',
    rowWaited           = 'Waiting %s',
    rowCaller           = 'Caller id %d',
    rowHelp             = 'Taking it routes you there and marks you busy. /%s drops it.',
    decideTitle         = 'Help this person?',
    promptAccept        = 'Accept',
    promptDeny          = 'Deny',
    promptBack          = 'Back',
    promptAlert         = 'Call',
    fromZone            = ' from %s',

    -- call pay and restores
    payDone             = 'Call complete: %s for a %d unit ride.',
    moneyCash           = '$%d',
    moneyGold           = '%d gold',
    moneyRol            = '%d rol',
    restored            = 'Your belongings have been returned.',
}

-- text for the current language, falling back to English per key
function L(key, ...)
    local lang = Config and Config.General and Config.General.language or 'en'
    local set = Locales[lang]
    local text = (set and set[key]) or Locales.en[key] or key
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, text, ...)
        if ok then return out end
    end
    return text
end
