/* pup-loading | loading screen config (see README.md) */

window.LoadingConfig = {

    /* ------------------------------------------------------------------ */
    /* TEXT                                                                */
    /* ------------------------------------------------------------------ */
    title:    'DUSK TILL DAWN',             // big name in the middle
    subtitle: 'THE WEST LIVES AFTER DARK',  // line under the name ('' = hidden)
    showRule: true,                         // thin gold line between the two

    /* Optional logo above the title. '' = no logo. */
    logo: {
        image:  '',                         // e.g. 'img/logo.png'
        height: 14,                         // % of screen height
    },

    /* ------------------------------------------------------------------ */
    /* COLOURS & FONTS                                                     */
    /* ------------------------------------------------------------------ */
    colors: {
        text:       '#f3ead7',  // title, tips
        textDim:    '#b9ae95',  // subtitle, labels, status
        accent:     '#c9a24b',  // progress bar, rule, music meter
        accentDark: '#8a6c2f',  // start of the progress bar gradient
        background: '#0b0906',  // behind the image while it loads
    },
    titleFont: 'fonts/oswald.ttf',          // font for title/labels ('' = Georgia)

    /* ------------------------------------------------------------------ */
    /* BACKGROUND                                                          */
    /* ------------------------------------------------------------------ */
    background: {
        // no image ships: put your own in html/img/ and list it, e.g. ['img/banner.jpg']
        images:       [],                   // [] = plain dark background; one image = static, several = slideshow
        slideSeconds: 12,                   // time per image in a slideshow
        drift:        true,                 // slow zoom so a still image never looks frozen
        darken:       1.0,                  // overlay strength: 0 = none, 1 = default, 1.5 = darker
    },

    /* ------------------------------------------------------------------ */
    /* TIPS                                                                */
    /* ------------------------------------------------------------------ */
    tips: {
        enabled:       true,
        label:         'WORD FROM THE TRAIL',
        rotateSeconds: 6,
        randomStart:   true,                // start on a random tip each load
        list: [
            'Type /perks to open your deck. Spend points as you earn them — every trade has its own line.',
            'Perks are not just combat. Distillers, hustlers, outlaws and hunters all have their own.',
            'A moonshine hideout pays better than a day job — and draws far more attention.',
            'Mash, then alcohol, then moonshine. The still takes its time; the law does not wait.',
            'Sell moonshine to the right stranger. The wrong one takes the crate and leaves you nothing.',
            'The marketplace runs on buy-orders. Post what you want and let the frontier bring it in.',
            'A listing license is one per name. Choose your market town carefully.',
            'A gunsmith can do more than sell you a rifle — engraving, materials, tints, and repairs.',
            'A worn weapon jams and hits soft. Keep it clean, or pay the smith to set it right.',
            'Buy a home, take the keys, and furnish it however you please. Locked doors keep honest folk out.',
            'Ride with a clan. Camps, shared ground, and a name people learn to recognise.',
            'Gangs hold territory. Holding it is the easy part.',
            'The law keeps records. Warrants, bounties and prison time all outlive the arrest.',
            'Badges are earned by rank, and only mean something while you are on duty.',
            'Your horse is your life. Feed it, brush it, and load the saddlebags.',
            'Eat and drink. Hunger and thirst wear you down long before a bullet does.',
            'A doctor beats a bandage. Find one before the bleeding decides for you.',
            'Trains, ranches, farms and the hunt all pay honest coin — if honest is your road.',
            'Ride with company: /pose puts your posse on the map.',
            'Letters still travel. Check your mail — deals, warrants and bad news all arrive that way.',
        ],
    },

    /* ------------------------------------------------------------------ */
    /* TEAM (right-hand panel)                                             */
    /* ------------------------------------------------------------------ */
    team: {
        enabled: true,
        label:   'Owners and Staff',
        groups: [
            { rank: 'Owners',            names: ['Puppet'] },
            { rank: 'Management',        names: [] },
            { rank: 'Head Admins',       names: [] },
            { rank: 'Admins',            names: [] },
            { rank: 'Senior Moderators', names: [] },
            { rank: 'Moderators',        names: [] },
            { rank: 'Support',           names: [] },
        ],
    },

    /* ------------------------------------------------------------------ */
    /* GUIDES (left-hand panel)                                            */
    /* ------------------------------------------------------------------ */
    guide: {
        enabled:       true,
        label:         'New to the Frontier',
        rotateSeconds: 14,
        pages: [
            {
                title: 'Your First Steps',
                rows: [
                    { key: 'I',  text: 'Open your inventory.' },
                    { key: 'X',  text: 'Show or hide your hotbar.' },
                    { key: 'F1', text: 'Open the radial menu.' },
                ],
                lines: [
                    'Eat and drink. Hunger and thirst wear you down long before a bullet does.',
                ],
            },
            {
                title: 'Handy Commands',
                rows: [
                    { key: '/perks',  text: 'Your levels, points and perks, with a guide inside.' },
                    { key: '/myid',   text: 'Look at your own ID card.' },
                    { key: '/idcard', text: 'Show your ID to the closest player.' },
                    { key: '/mail',   text: 'Your letters.' },
                    { key: '/pose',   text: 'Ride together in a posse.' },
                    { key: '/emotes', text: 'Set up your emotes.' },
                    { key: '/hud',    text: 'Move your HUD around.' },
                ],
            },
            {
                title: 'Making an Honest Living',
                intro: 'Every trade pays, and earns you Honest Work experience.',
                lines: [
                    'Hunting and skinning',
                    'Farming, with /farm for your plots and crop guide',
                    'Ranching, mining, lumber and gold panning',
                    'Fishing and taming wild horses',
                    'Crafting and gunsmithing',
                ],
            },
            {
                title: 'The Outlaw Road',
                intro: 'Crime pays better, and it earns Outlaw experience. The law keeps records.',
                lines: [
                    'Robberies and wagon jobs',
                    'Moonshine stills and drug sales',
                    'Fencing stolen goods and grave robbing',
                    'Use /gang to accept a gang invite',
                ],
            },
            {
                title: 'When Things Go Wrong',
                rows: [
                    { key: '/alertmedic', text: 'Call for a doctor.' },
                    { key: '/calert',     text: 'Cancel your alert.' },
                    { key: '/alertlaw',   text: 'Call for the law.' },
                    { key: '/jailtime',   text: 'See how long you have left.' },
                    { key: '/lawyer',     text: 'Ask for a lawyer.' },
                ],
            },
        ],
    },

    /* ------------------------------------------------------------------ */
    /* PROGRESS BAR                                                        */
    /* ------------------------------------------------------------------ */
    progress: {
        enabled:     true,
        statusStart: 'Loading the frontier...',
        // text shown at each loading stage the game reports
        statuses: {
            startInitFunction:      'Waking the frontier...',
            startDataFileEntries:   'Reading the land...',
            initFunctionInvoking:   'Raising the towns...',
            performMapLoadFunction: 'Laying the rails...',
            onLogLine:              'Almost there...',
        },
    },

    /* ------------------------------------------------------------------ */
    /* MUSIC                                                               */
    /* ------------------------------------------------------------------ */
    music: {
        enabled:       true,
        // no music ships: put your own theme.mp3 in html/audio/ and list it, e.g. ['audio/theme.mp3']
        tracks:        [],                  // [] = silent, controls hidden; one track loops; several play in order
        shuffle:       false,               // random order for several tracks
        volume:        35,                  // starting volume 0-100 (players can change it)
        fadeInSeconds: 4,
        showControls:  true,                // pause / volume box, bottom-right
    },

    /* ------------------------------------------------------------------ */
    /* LINKS (bottom-left, text only)                                      */
    /* ------------------------------------------------------------------ */
    links: [],
};
