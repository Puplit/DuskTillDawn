-- bathing | player text. Prompt labels by prompt id (%s = the price);
-- messages take the price as %.2f.

BathhouseLocale = {
    prompts = {
        start  = 'Take a bath(%s$)',
        scrub  = 'Wash',
        deluxe = 'Order a luxury bath(%s$)',
        exit   = 'Exit',
    },
    blipName     = 'Bath House',
    exitHint     = '[G] Climb out of the tub',
    occupied     = 'Someone is already in this bath. Wait your turn.',
    noCashBath   = 'You need $%.2f for a bath',
    noCashDeluxe = 'You need $%.2f for the deluxe service',
}
