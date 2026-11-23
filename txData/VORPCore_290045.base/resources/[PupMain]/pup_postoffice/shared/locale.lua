-- pup_postoffice | game tip wording. %s / %d are filled in by the code.

L = {
    -- offices and the window
    needOffice        = 'You must be standing at a mail office.',
    promptText        = 'Press G to use the post',
    menuTitle         = 'Post Office',
    needRegister      = 'You have no PO box yet. Rent one at any mail office.',
    menuRegister      = 'Rent a PO box',
    menuOpen          = 'Open your mailbox',
    restrained        = 'You cannot do that while restrained.',
    windowFailed      = 'The mail window did not open. Give it a moment and try again.',
    notEnoughCash     = 'You do not have enough cash.',
    alreadyHaveBox    = 'You already rent a PO box. Use /%s to read your mail.',
    registered        = 'Your PO box is ready: PO Box %d',
    registerFailed    = 'The clerk could not file your box. Your money was returned.',

    -- letters
    tooManyRecipients = 'A letter can be addressed to %d people at most.',
    tooLong           = 'That letter is too long to send.',
    cooldown          = 'Your last pigeon is still in the air. Wait a moment.',
    invalidAddresses  = 'These addresses do not exist: %s',
    bookFull          = 'Your address book has no room left.',
    folderLimit       = 'You cannot make any more folders.',
    folderBadName     = 'That folder name cannot be used.',

    -- business
    bizNoBox          = 'Your business has no PO box.',
    bizNoRank         = 'Your rank may not write letters for %s.',
    bizNotEmployed    = 'You are not employed by a business.',
    bizNotBoss        = 'Only the owner can open a business PO box.',
    bizHasBox         = '%s already has a PO box.',
    bizEmpty          = 'Type a PO address, for example val556.',
    bizFormat         = 'A PO address is 3 letters then 3 numbers, for example val556.',
    bizTakenFree      = '%s is in use. %s is free.',
    bizTakenNone      = '%s is in use. Try other letters.',
    bizRegisterFail   = 'That PO address could not be filed. Try another.',
    bizRegistered     = 'Letters for %s now go to %s.',
    bizRegisterFirst  = 'Open a business PO box first.',
    bizSame           = 'That is your PO address already.',
    bizNoLedger       = 'This business has no ledger to pay from.',
    bizCantAfford     = 'A new PO address costs $%d. The ledger holds $%d.',
    bizChangeFail     = 'The PO address could not be changed. Nothing was charged.',
    bizChangedPaid    = 'PO address is now %s. $%d came out of the ledger.',
    bizChanged        = 'PO address is now %s.',
    bizActivity       = 'Changed PO address from %s to %s for $%d',

    -- groups
    grpNeedBox        = 'Rent a PO box of your own first.',
    grpNoTitle        = 'The group needs a name.',
    grpTooMany        = 'You already run %d groups.',
    grpOwnerRename    = 'Only the owner of the group can rename it.',
    grpOwnerAdd       = 'Only the owner of the group can add people.',
    grpNotNumber      = 'That is not a PO box number.',
    grpNoSuchBox      = 'No one rents PO Box %d.',
    grpFull           = 'That group has no room left.',
    grpAlready        = 'They are already in that group.',
    grpAdded          = 'You were added to a group: %s',
    grpOwnerRemove    = 'Only the owner of the group can remove people.',
    grpOwnerDisband   = 'Only the owner of the group can disband it.',

    -- chats
    chatSelf          = 'That is your own PO box.',
    chatBlocked       = 'You blocked PO Box %d. Unblock it in your address book first.',
    chatNoSuchBiz     = 'No business uses the PO address %s.',
    chatOwnBiz        = 'That is your own business. Answer its customers from the business side.',
    chatBlockFull     = 'You cannot block any more boxes.',
    chatLoading       = 'The post office is still opening. Try again in a moment.',
    chatTooShort      = 'Write a little more than that.',
    chatRepeat        = 'You just sent that.',
    chatNoThread      = 'That message is no longer there to reply to.',
    bizBlockedYou     = 'This business is not taking your messages.',
    bizBlocked        = 'PO Box %d is blocked: it can no longer write to the business.',
    bizUnblocked      = 'PO Box %d is unblocked.',
    bizBlockFull      = 'The business block list is full.',
    bizByChat         = 'Businesses take messages by chat, not by letter: open Chats and message %s.',
    chatSlowDown      = 'The telegraph clerk asks you to slow down. Wait %d seconds.',

    -- admin
    adminMoved        = 'Your mail now goes to PO Box %d.',
    adminCreated      = 'A PO box was opened for you: PO Box %d',
}

-- Reasons handed back to vorp_admin, shown to the admin as they are.
L.admin = {
    noTarget     = 'no target',
    noCharacter  = 'no character',
    notLoaded    = 'that player is not loaded',
    badNumber    = 'PO Box must be a whole number above 0',
    taken        = 'PO Box %d is already taken',
    playerNoBox  = 'that player has no PO Box - use CREATE PO BOX',
    charNoBox    = 'that character has no PO Box - use Register',
    hasBox       = 'they already have PO Box %d',
    noBusiness   = 'no business given',
    takenFree    = '%s is taken, %s is free',
    takenNone    = '%s is taken, try different letters',
    setFailed    = 'could not set that PO address, try another',
    dbFailed     = 'the database refused the change',
}
