// pup-pinboard | preview outside the game
// Opening html/index.html through a local web server in a normal browser loads this file (never in game):
// it pretends to be the server so the screen can be looked at and tried. Add ?night for night, ?empty for
// an empty board. Nothing here reaches the game or the database.

const TEXTS = {
    prompt_read: 'Read the notices',
    board_title: '%s Notice Board', pin_notice: 'Pin a Notice', search_placeholder: 'Search the board...',
    filter_all: 'All', filter_mine: 'Mine', yours: 'Yours', loading: 'Loading...',
    empty_all: 'Nothing pinned here yet', empty_section: 'Nothing under %s yet',
    empty_mine: 'You have nothing pinned here', empty_search: 'No notices match "%s"', pin_first: 'Pin the first one',
    leave: 'Leave',
    section_sale: 'For Sale', section_buying: 'Buying & Wanted', section_jobs: 'Jobs & Services', section_notices: 'Notices & Events',
    section_sale_hint: 'Horses, goods, property, wagons', section_buying_hint: 'Looking to buy, wanted posters',
    section_jobs_hint: 'Hiring hands, work, services for hire', section_notices_hint: 'Announcements, meetings, lost and found',
    po_box: 'PO Box %s', write_to: 'Write to PO Box %s', fringe_slip: 'Box %s', tear_slip: 'Tear a Slip',
    slip_taken: 'You tore off a slip: PO Box %s. Write to them with /mail.',
    choose_section: 'Where does it go?', choose_kind: 'What are you pinning?', kind_text: 'Write a Notice',
    kind_image: 'Pin a Picture', pinning_under: 'Pinning under: %s', cancel: 'Cancel',
    board_unavailable: 'The board could not be read. Try again in a moment.',
    no_answer: 'No answer from the board. Try again in a moment.',
    close_notice: 'Close', pin: 'Pin', unpin: 'Unpin', discard: 'Discard', write_first: 'Write something first.',
    eco_boost: 'Eco Boost', eco_available: 'Available', eco_resume: 'Resume: %s / %s', eco_active: 'Active: %s / %s',
    eco_cooldown: 'Available in: %s', eco_completed: 'Completed\nAvailable in: %s', eco_disabled: 'Unavailable',
    paper: 'Paper', style_heading: 'Heading', style_body: 'Text', add_line: 'Add line', remove_line: 'Remove line',
    align_left: 'Left', align_center: 'Centre', align_right: 'Right',
    heading_hint: 'Heading', body_hint: 'Your text here',
    link_label: 'Image link', link_check: 'Check image', picture_placeholder: 'Your picture shows here',
    link_help: 'Paste a direct link to an image. It must end in .png, .jpg, .jpeg, .gif or .webp.',
    scope_question: 'Where should this go?', scope_here: 'This board only', scope_all: 'Every board in the state',
    unpin_question: 'Take this down?', unpin_confirm: 'Take it down', unpin_cancel: 'Leave it up',
    pinned_ok: 'You pinned a notice to the board.', unpinned_ok: 'You took a notice down.',
    not_allowed: 'You are not allowed to pin that here.', too_far: 'Step up to the board first.',
    too_fast: 'Wait a few seconds before pinning again.', too_many: 'You already have as many notices up as you may.',
    too_long: 'That notice is too long.', link_missing: 'Enter an image link first.',
    link_invalid: 'That is not a valid image link.', link_broken: 'That image could not be loaded.',
    link_blocked: 'That image host is not allowed.',
};

const ME = 7;
const BOXES = { 7: 1042, 3: 1007, 4: 1311, 5: 1188, 6: 1025 };
let nextId = 20;
const text = (id, by, paper, section, lines) => ({ id, kind: 'text', mine: by === ME, section, poBox: BOXES[by],
    content: { paper, section, lines: lines.map(([style, align, t]) => ({ style, align, text: t })) } });
const notices = new URLSearchParams(location.search).has('empty') ? [] : [
    text(19, ME, 5, 'sale', [['heading', 'center', 'Horse for Sale'], ['body', 'left', 'Fine Kentucky Saddler mare, five years old, calm under fire.\nAsking $180.']]),
    text(18, 3, 1, 'jobs', [['heading', 'center', 'Hands Wanted'], ['body', 'center', 'Emerald Ranch spring drive.\nGood pay, hot meals, a bunk.']]),
    text(17, 4, 3, 'notices', [['heading', 'left', 'Lost Dog'], ['body', 'left', 'Brown hound answering to Biscuit. Last seen near the saloon. Reward.']]),
    text(16, 5, 4, 'notices', [['heading', 'center', 'Town Meeting'], ['body', 'center', 'Saturday at sundown in the church hall.']]),
    text(15, ME, 6, 'buying', [['heading', 'right', 'Buying Pelts'], ['body', 'right', 'Perfect beaver and fox pelts, fair prices paid.']]),
    text(14, 6, 2, 'sale', [['heading', 'center', 'Wagon for Sale'], ['body', 'left', 'Sturdy cart, new wheels. $95 or a good trade.']]),
    text(13, 3, 1, 'jobs', [['heading', 'center', 'Blacksmith'], ['body', 'center', 'Shoeing, repairs and fine ironwork.']]),
];

function answer(type, payload, deliver) { deliver(Object.assign({ type }, payload)); }

export function startPreview(useFakeServer) {
    useFakeServer((name, body, deliver) => {
        const rt = body.reply;
        switch (name) {
            case 'listNotices':
                return answer(rt, { ok: true, notices, canRemoveAny: false,
                    player: { charId: ME, job: '', grade: 0, allBoards: true } }, deliver);
            case 'pinText':
            case 'pinPicture':
                notices.unshift({ id: nextId++, kind: name === 'pinText' ? 'text' : 'picture',
                    mine: true, section: body.section, poBox: BOXES[ME], content: body });
                return answer(rt, { ok: true }, deliver);
            case 'unpinNotice': {
                const i = notices.findIndex((n) => n.id === body.id);
                if (i !== -1) notices.splice(i, 1);
                return answer(rt, { ok: true }, deliver);
            }
            case 'ecoStatus':
                return answer(rt, { ok: true, status: { state: 'available' } }, deliver);
            case 'isNight':
                return answer(rt, { ok: true, night: false }, deliver);
            case 'close':
                return setTimeout(() => window.postMessage(showMessage(), '*'), 600);
        }
    });
    window.postMessage(showMessage(), '*');
}

function showMessage() {
    const night = new URLSearchParams(location.search).has('night');
    return {
        type: 'show', night, texts: TEXTS,
        settings: { Notices: { refusedHosts: [] }, Screen: { toastMs: 4000, confirmToast: true } },
        player: {}, board: { city: 'Valentine' },
    };
}
