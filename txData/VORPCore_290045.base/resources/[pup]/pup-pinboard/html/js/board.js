// pup-pinboard | the board screen
//
// From the game (client/main.lua):
//   { type = 'show', night, settings, texts, player, board }
//   { type = 'hide' }
//   plus the replies to the calls below
// To the game: listNotices, pinText, pinPicture, unpinNotice, isNight, ecoStatus, ecoActivate, close

import {
    IN_GAME, post, deliver, useFakeServer, setTexts, L, el, toast, setToastDuration,
    topLayer, closeAllLayers,
} from './shared.js';
import { SECTIONS, sectionOf, noticeCard, openDetail } from './notices.js';
import { openPinChooser, openWriteForm, openPictureForm } from './create.js';

const $ = (id) => document.getElementById(id);

const ui = {
    board: $('board'),
    title: $('board-title'),
    search: $('search'),
    pin: $('btn-pin'),
    eco: $('btn-eco'),
    ecoTitle: document.querySelector('#btn-eco .eco__title'),
    ecoState: document.querySelector('#btn-eco .eco__state'),
    leave: $('btn-leave'),
    tabs: $('tabs'),
    cork: $('cork'),
    notices: $('notices'),
    empty: $('empty'),
    emptyText: $('empty-text'),
    emptyPin: $('empty-pin'),
};

const state = {
    open: false,
    settings: {},
    board: {},          // this board's entry from config/boards.lua
    player: {},         // who is reading, from the server
    notices: [],        // what the server sent, newest first
    loaded: false,
    canRemoveAny: false,
    tab: 'all',         // 'all', a section id, or 'mine'
    torn: {},           // notice id -> slips this player tore off this visit
    search: '',
    ecoState: 'disabled',
    dayTimer: null,
    listSeq: 0,
};

// ---------- who may do what (the server checks all of it again) ----------

function kindOff(kind) {
    const all = (state.settings.Notices || {}).kinds || {};
    const here = state.board.kinds || {};
    return all[kind] === false || here[kind] === false;
}

function jobAllowed() {
    const need = state.board.jobs;
    if (!need || typeof need !== 'object' || Object.keys(need).length === 0) return true;
    const job = String(state.player.job || '');
    if (!(job in need)) return false;
    return (Number(state.player.grade) || 0) >= (Number(need[job]) || 0);
}

function canPin(kind) { return jobAllowed() && !kindOff(kind); }
function canPinAnything() { return canPin('text') || canPin('picture'); }

function refreshButtons() {
    ui.pin.disabled = !canPinAnything();
}

// ---------- notices ----------

function isMine(item) { return item.mine === true; }

function canRemove(item) {
    return state.canRemoveAny || isMine(item);
}

// everything a search can find on a notice: its words, its section and its PO box
function searchText(item) {
    const c = item.content || {};
    const words = Array.isArray(c.lines) ? c.lines.map((l) => (l && l.text) || '').join(' ') : '';
    return (words + ' ' + L('section_' + sectionOf(item)) + ' ' + (item.poBox || '')).toLowerCase();
}

function inTab(item, tab) {
    if (tab === 'all') return true;
    if (tab === 'mine') return isMine(item);
    return sectionOf(item) === tab;
}

function shownNotices() {
    const q = state.search.trim().toLowerCase();
    return state.notices.filter((item) => inTab(item, state.tab) && (!q || searchText(item).includes(q)));
}

function buildTabs() {
    const tabs = [['all', L('filter_all')], ...SECTIONS.map((id) => [id, L('section_' + id)]), ['mine', L('filter_mine')]];
    ui.tabs.replaceChildren(...tabs.map(([id, label]) => {
        const t = el('button', `tab tab--${id}` + (id === state.tab ? ' is-on' : ''));
        t.type = 'button';
        t.dataset.tab = id;
        t.appendChild(el('span', 'tab__label', label));
        t.appendChild(el('span', 'tab__count', '0'));
        return t;
    }));
}

function render() {
    // counts on every tab
    ui.tabs.querySelectorAll('.tab').forEach((t) => {
        t.classList.toggle('is-on', t.dataset.tab === state.tab);
        t.querySelector('.tab__count').textContent = state.notices.filter((n) => inTab(n, t.dataset.tab)).length;
    });

    const list = shownNotices();
    ui.notices.replaceChildren(...list.map((item, i) =>
        noticeCard(item, isMine(item), () => openDetail(list, i, canRemove, removeNotice, tearSlip), state.torn[item.id])));

    if (list.length > 0) {
        ui.empty.classList.add('hidden');
        return;
    }
    let text;
    let offerPin = false;
    if (state.search.trim()) text = L('empty_search', state.search.trim());
    else if (state.tab === 'mine') text = L('empty_mine');
    else if (state.tab === 'all') { text = L('empty_all'); offerPin = true; }
    else { text = L('empty_section', L('section_' + state.tab)); offerPin = true; }
    ui.emptyText.textContent = text;
    ui.emptyPin.classList.toggle('hidden', !(offerPin && canPinAnything()));
    ui.empty.classList.remove('hidden');
}

function showLoading(text) {
    ui.notices.replaceChildren();
    ui.emptyText.textContent = text;
    ui.emptyPin.classList.add('hidden');
    ui.empty.classList.remove('hidden');
}

function loadNotices() {
    const mySeq = ++state.listSeq;
    if (!state.loaded) showLoading(L('loading'));
    post('listNotices', {}, (reply) => {
        if (mySeq !== state.listSeq || !state.open) return; // an older request, or the board closed
        if (!reply.ok) {
            showLoading(L('board_unavailable'));
            return;
        }
        // the list reply carries who you are, so the buttons are right even on the very first open
        if (reply.player && typeof reply.player === 'object') {
            state.player = reply.player;
            refreshButtons();
        }
        state.notices = Array.isArray(reply.notices) ? reply.notices : [];
        state.canRemoveAny = reply.canRemoveAny === true;
        state.loaded = true;
        render();
    });
}

// a call that pins or unpins; resolves true on success, shows the refusal otherwise
function send(name, data) {
    return new Promise((resolve) => {
        post(name, data, (reply) => {
            if (reply.ok) return resolve(true);
            toast(L(reply.timedOut ? 'no_answer' : (reply.reason || 'not_allowed')), true);
            resolve(false);
        });
    });
}

function confirmToast(key) {
    if ((state.settings.Screen || {}).confirmToast === true) toast(L(key));
}

async function saveNotice(name, content) {
    const ok = await send(name, content);
    if (ok) {
        confirmToast('pinned_ok');
        // show the section it went into, so the new notice is right there
        state.tab = content.section || state.tab;
        state.search = '';
        ui.search.value = '';
        loadNotices();
    }
    return ok;
}

// a slip torn off a notice: the box number in a message, and one slip fewer on the board.
// Only this player sees the slip go, and only while the board is open.
function tearSlip(item) {
    state.torn[item.id] = (state.torn[item.id] || 0) + 1;
    toast(L('slip_taken', item.poBox));
    render();
}

async function removeNotice(item) {
    const ok = await send('unpinNotice', { id: item.id });
    if (ok) {
        confirmToast('unpinned_ok');
        loadNotices();
    }
    return ok;
}

// ---------- pinning ----------

function startPinning() {
    if (!canPinAnything()) return;
    openPinChooser({
        section: SECTIONS.includes(state.tab) ? state.tab : null,
        canText: canPin('text'),
        canPicture: canPin('picture'),
        onPick: (section, kind) => {
            const common = {
                section,
                allBoardsAllowed: state.player.allBoards === true,
            };
            if (kind === 'picture') {
                openPictureForm(Object.assign(common, {
                    refusedHosts: [].concat((state.settings.Notices || {}).refusedHosts || [], state.board.refusedHosts || []),
                    onSave: (content) => saveNotice('pinPicture', content),
                }));
            } else {
                openWriteForm(Object.assign(common, {
                    onSave: (content) => saveNotice('pinText', content),
                }));
            }
        },
    });
}

// ---------- eco boost (owned by pup-misc; the button only mirrors it) ----------

function money(v) {
    const n = Number(v) || 0;
    return '$' + (Number.isInteger(n) ? n : n.toFixed(2));
}

function renderEco(status) {
    status = status || { state: 'disabled' };
    state.ecoState = status.state || 'disabled';
    let text;
    switch (state.ecoState) {
        case 'available':
            text = (Number(status.earned) || 0) > 0
                ? L('eco_resume', money(status.earned), money(status.cap))
                : L('eco_available');
            break;
        case 'active': text = L('eco_active', money(status.earned), money(status.cap)); break;
        case 'cooldown': text = L('eco_cooldown', status.remaining_text || ''); break;
        case 'completed': text = L('eco_completed', status.remaining_text || ''); break;
        default: text = L('eco_disabled');
    }
    ui.ecoState.textContent = text;
    ui.eco.disabled = state.ecoState !== 'available';
}

// ---------- day and night ----------

function setNight(night) { ui.board.classList.toggle('is-night', !!night); }

function watchDayNight() {
    clearInterval(state.dayTimer);
    state.dayTimer = setInterval(() => {
        if (state.open) post('isNight', {}, (r) => { if (r.ok) setNight(r.night); });
    }, 60000);
}

// ---------- open / close ----------

function applyTexts() {
    ui.pin.textContent = L('pin_notice');
    ui.emptyPin.textContent = L('pin_first');
    ui.search.placeholder = L('search_placeholder');
    ui.ecoTitle.textContent = L('eco_boost');
    ui.leave.textContent = L('leave');
}

const asObject = (v) => (v && typeof v === 'object') ? v : {};

function show(msg) {
    setTexts(msg.texts);
    state.settings = asObject(msg.settings);
    state.board = asObject(msg.board);
    state.player = asObject(msg.player);
    state.notices = [];
    state.loaded = false;
    state.tab = 'all';
    state.search = '';
    state.torn = {};
    setToastDuration((state.settings.Screen || {}).toastMs);

    closeAllLayers();
    applyTexts();
    ui.search.value = '';
    ui.title.textContent = L('board_title', state.board.city || '');
    buildTabs();
    setNight(msg.night);
    refreshButtons();

    state.open = true;
    ui.board.classList.remove('hidden');
    ui.cork.scrollTop = 0;

    renderEco(null);
    post('ecoStatus', {}, (r) => renderEco(r.status));
    loadNotices();
    watchDayNight();
}

function hide() {
    state.open = false;
    clearInterval(state.dayTimer);
    closeAllLayers();
    ui.search.blur();
    ui.board.classList.add('hidden');
}

function leave() {
    post('close');
    hide(); // the game sends 'hide' too; hiding here as well means the screen never lingers
}

// ---------- wiring ----------

ui.leave.addEventListener('click', leave);
ui.pin.addEventListener('click', startPinning);
ui.emptyPin.addEventListener('click', startPinning);

ui.tabs.addEventListener('click', (e) => {
    const t = e.target.closest('.tab');
    if (!t || t.dataset.tab === state.tab) return;
    state.tab = t.dataset.tab;
    ui.cork.scrollTop = 0;
    render();
});

ui.search.addEventListener('input', () => {
    state.search = ui.search.value;
    if (state.loaded) render();
});

ui.eco.addEventListener('click', () => {
    if (state.ecoState !== 'available') return;
    ui.eco.disabled = true;
    post('ecoActivate', {}, (r) => renderEco(r.status));
});

window.addEventListener('keydown', (e) => {
    if (!state.open || (e.key !== 'Escape' && e.key !== 'Backspace')) return;
    const typing = e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA');
    if (typing && e.key === 'Backspace') return;
    const layer = topLayer();
    if (layer) { layer.esc(); return; }
    // Esc in the search box clears it first, then a second Esc leaves
    if (e.target === ui.search && ui.search.value) {
        ui.search.value = '';
        state.search = '';
        render();
        return;
    }
    leave();
});

window.addEventListener('message', (e) => {
    const msg = e.data || {};
    if (deliver(msg)) return;
    if (msg.type === 'show') show(msg);
    else if (msg.type === 'hide') hide();
});

// ---------- outside the game: a pretend server, to look at the screen in a normal browser ----------

if (!IN_GAME) {
    import('./preview.js').then((m) => m.startPreview(useFakeServer)).catch(() => {});
}
