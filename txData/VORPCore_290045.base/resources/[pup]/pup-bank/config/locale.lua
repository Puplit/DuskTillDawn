-- pup-bank | text players see. Change the words, keep the keys and the %s.

Locale = {
    -- at the counter
    promptGroup   = "Bank Counter",
    promptOpen    = "Do Business",

    -- results of a deposit or withdrawal (%s = the amount)
    paidIn        = "$%s is now in your account here.",
    tookOut       = "The clerk counts out $%s for you.",
    refused       = "The clerk shakes his head. That amount won't do.",

    -- the amount panel
    amountField   = "How much ($)",
    send          = "Hand it over",

    -- app frame and tabs
    appTitle      = "BANK",
    tabAccount    = "Account",
    tabPayIn      = "Deposit",
    tabTakeOut    = "Withdraw",
    tabBranches   = "Branches",
    tabTeller     = "Teller",

    -- account tab
    accountSub    = "What this branch holds in your name.",
    heldHere      = "Held at this branch",
    ledgerTitle   = "Latest entries",
    colWhen       = "When",
    colEntry      = "Entry",
    colAmount     = "Amount",
    colBalance    = "Left after",
    loading       = "The clerk is looking through the ledger...",
    ledgerEmpty   = "Nothing written in the ledger at this branch yet.",
    clearButton   = "Clear Statement",
    clearedTip    = "Your statement here starts fresh.",

    -- ledger entry names
    entryIn       = "DEPOSIT",
    entryOut      = "WITHDRAW",
    entryXferIn   = "TRANSFER IN",
    entryXferOut  = "TRANSFER OUT",
    entryCredit   = "CREDIT",
    entryDebit    = "DEBIT",

    -- deposit / withdraw tabs
    payInTitle    = "Deposit Cash",
    payInSub      = "Put pocket money into this branch.",
    payInButton   = "Deposit Cash",
    takeOutTitle  = "Withdraw Cash",
    takeOutSub    = "Take money from this branch as cash.",
    takeOutButton = "Withdraw Cash",

    -- branches tab
    branchesSub   = "Every account you keep, seen from any counter.",
    colBranch     = "Branch",
    allTotal      = "All branches together",
    thisBranch    = "  (this counter)",
    branchesNone  = "The clerk could not find your other accounts.",

    -- how long ago a ledger entry was made
    agoNow        = "moments ago",
    agoMinutes    = "%d min ago",
    agoHours      = "%d hr ago",
    agoDays       = "%d days ago",
}
