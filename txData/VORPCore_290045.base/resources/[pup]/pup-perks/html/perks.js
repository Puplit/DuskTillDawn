/* pup-perks | UI runtime. NUI() and iconSVG() are copied from pup-ui so there is no load-order dependency. */
const RESOURCE = 'pup-perks';
const NUI = (name, data) => fetch(`https://${RESOURCE}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
}).catch(() => {});

const ICON_SVG = {
    star:    '<path d="M12 2.6l2.7 5.8 6.3.7-4.7 4.3 1.3 6.3L12 16.9 6.1 19.9l1.3-6.3L2.7 9.1l6.3-.7z"/>',
    money:   '<path d="M9.4 2.2h5.2l-1.4 2.9a1 1 0 0 1-.9.6h-.6a1 1 0 0 1-.9-.6z"/><path d="M12 6.1c-2.6 1.6-6 4.9-6 9.1a6 6 0 0 0 12 0c0-4.2-3.4-7.5-6-9.1z"/>',
    skull:   '<path fill-rule="evenodd" d="M12 2a8 8 0 0 0-8 8c0 2.8 1.4 4.6 3 5.6V19a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2v-3.4c1.6-1 3-2.8 3-5.6a8 8 0 0 0-8-8zM9 9.2a1.8 1.8 0 1 0 0 3.6 1.8 1.8 0 0 0 0-3.6zm6 0a1.8 1.8 0 1 0 0 3.6 1.8 1.8 0 0 0 0-3.6z"/>',
    bell:    '<path d="M12 2a2 2 0 0 0-2 2v.7C7.1 5.5 5 8.2 5 11.5V15l-2 2v1h18v-1l-2-2v-3.5c0-3.3-2.1-6-5-6.8V4a2 2 0 0 0-2-2z"/><path d="M9.8 20a2.2 2.2 0 0 0 4.4 0z"/>',
    fire:    '<path d="M12 2c1 3-1 4.2-2.1 6-1.1 1.8-2.9 3.4-2.9 6.1a5 5 0 0 0 10 0c0-2-1-3.6-1.6-4.6-.3 1-.9 1.8-1.7 2.1.6-2.3-.5-4.7-1.7-6.6z"/>',
    heart:   '<path d="M12 21C5 15.5 3 11.6 3 8.6A4.6 4.6 0 0 1 12 6.1 4.6 4.6 0 0 1 21 8.6c0 3-2 6.9-9 12.4z"/>',
    cross:   '<path d="M9.2 2.4h5.6v6.4h6.4v5.6h-6.4v6.4H9.2v-6.4H2.8V8.8h6.4z"/>',
    flag:    '<rect x="4.4" y="2" width="1.9" height="20" rx="0.6"/><path d="M6.8 3.2h12.8l-2.6 4 2.6 4H6.8z"/>',
    shield:  '<path d="M12 2.2l8 3v5.8c0 5-3.4 8.7-8 10-4.6-1.3-8-5-8-10V5.2z"/>',
    warning: '<path fill-rule="evenodd" d="M12 3.2 21.6 20H2.4zM11 9.2v5h2v-5zm0 6.6v2h2v-2z"/>',
    check:   '<path d="M4.5 12.5l4.8 4.8L19.5 6.6" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>',
    x:       '<path d="M6.2 6.2l11.6 11.6M17.8 6.2 6.2 17.8" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/>',
    info:    '<path fill-rule="evenodd" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm-1 8v7h2v-7zm0-3.6v2h2v-2z"/>',
    user:    '<path d="M12 12.2a4.6 4.6 0 1 0 0-9.2 4.6 4.6 0 0 0 0 9.2zm0 1.8c-4.5 0-8 2.4-8 5.6V21h16v-1.4c0-3.2-3.5-5.6-8-5.6z"/>',
    users:   '<path d="M8.2 11.2a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zm7.6 0a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm-7.6 1.8c-3.3 0-6 1.7-6 4V21h9v-1.6c0-1.5.6-2.8 1.7-3.7-1.3-.5-2.9-.7-4.7-.7zm7.6 0c-.6 0-1.1 0-1.7.2 1 .9 1.7 2.1 1.7 3.8V21H21v-1.4c0-2.3-2.4-3.6-5.2-3.6z"/>',
    key:     '<path fill-rule="evenodd" d="M14.5 2.5a6.5 6.5 0 0 0-6.1 8.7L2.5 17.1V21H7v-2h2v-2h2l1.3-1.3a6.5 6.5 0 1 0 2.2-13.2zM17 6.5a1.6 1.6 0 1 1-3.2 0 1.6 1.6 0 0 1 3.2 0z"/>',
    lock:    '<path fill-rule="evenodd" d="M7 10V8a5 5 0 0 1 10 0v2h.5a1.5 1.5 0 0 1 1.5 1.5v8A1.5 1.5 0 0 1 17.5 21h-11A1.5 1.5 0 0 1 5 19.5v-8A1.5 1.5 0 0 1 6.5 10zm2 0h6V8a3 3 0 0 0-6 0z"/>',
    clock:   '<path fill-rule="evenodd" d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 4.5h-2V13h5.5v-2H13z"/>',
    bank:    '<path d="M12 2 3 6.4V8h18V6.4zM5 9.2v7H4V18h16v-1.8h-1v-7h-2v7h-2.5v-7h-2v7h-2v-7H7.5v7H5z"/>',
    spade:   '<path d="M12 3C9 6 4.5 8.5 4.5 12.5A3.5 3.5 0 0 0 10 15l-1.2 4h6.4L14 15a3.5 3.5 0 0 0 5.5-2.5C19.5 8.5 15 6 12 3z"/>',
    /* app/dashboard sidebar set (clock/users reuse the entries above) */
    home:    '<path d="M12 3 2.5 11h2.6v9.5H10V15h4v5.5h4.9V11h2.6z"/>',
    medal:   '<path d="M7.4 2h3.1l1.6 4.4-2.6 1.3L6.2 4z"/><path d="M16.6 2h-3.1l-1.6 4.4 2.6 1.3L17.8 4z"/><path fill-rule="evenodd" d="M12 8.4a5.4 5.4 0 1 0 0 10.8 5.4 5.4 0 0 0 0-10.8zm0 2.3 1.1 2.2 2.4.3-1.7 1.7.4 2.4-2.2-1.1-2.2 1.1.4-2.4-1.7-1.7 2.4-.3z"/>',
    doc:     '<path fill-rule="evenodd" d="M6 2h7l5 5v15H6V2zm7 1.6V7h3.4zM8.4 10.6v1.6h7.2v-1.6zm0 3.4v1.6h7.2V14zm0 3.4V19h4.6v-1.6z"/>',
    chart:   '<path d="M3.4 3v16.4a1 1 0 0 0 1 1H21v-2H5.4V3z"/><path d="M8 12h2.2v6H8zM12 8h2.2v10H12zM16 14h2.2v4H16z"/>',
    box:     '<path fill-rule="evenodd" d="M12 2 3 6.5v11L12 22l9-4.5v-11L12 2zm0 2.2 6.1 3L12 10.3 5.9 7.2 12 4.2zM5 9v7.3l6 3V12L5 9zm14 0-6 3v7.3l6-3V9z"/>',
    coins:   '<path fill-rule="evenodd" d="M12 3.2c-3.9 0-7 1.2-7 2.9s3.1 2.9 7 2.9 7-1.2 7-2.9-3.1-2.9-7-2.9zM5 8.7v2.4c0 1.6 3.1 2.9 7 2.9s7-1.3 7-2.9V8.7c-1.3 1.3-4 2-7 2s-5.7-.7-7-2zm0 4.9v2.4c0 1.6 3.1 2.9 7 2.9s7-1.3 7-2.9v-2.4c-1.3 1.3-4 2-7 2s-5.7-.7-7-2z"/>',
    /* perk glyphs (pup-perks). Same flat single-colour style as the set above -
       they are drawn at 2.9vh inside a circle, so no fine detail survives. */
    lungs:   '<path d="M11 2h2v8.2h-2z"/><path d="M10.2 8.6c0 3-.5 5-2.1 7.2-1 1.4-2.6 2.6-3.9 2.6-1 0-1.7-.7-1.7-1.9 0-3.3 1-6.5 2.7-8.7C6.3 6.2 7.6 5.4 8.7 5.4c1 0 1.5.8 1.5 3.2zm3.6 0c0 3 .5 5 2.1 7.2 1 1.4 2.6 2.6 3.9 2.6 1 0 1.7-.7 1.7-1.9 0-3.3-1-6.5-2.7-8.7-1.1-1.6-2.4-2.4-3.5-2.4-1 0-1.5.8-1.5 3.2z"/>',
    hand:    '<path d="M8.4 11V4.6a1.3 1.3 0 0 1 2.6 0V10h.8V3.3a1.3 1.3 0 0 1 2.6 0V10h.8V4.8a1.3 1.3 0 0 1 2.6 0v8.4c0 4.3-2.4 7.8-6.1 7.8-2.2 0-3.7-1-5-3l-2.6-4.2a1.35 1.35 0 0 1 2-1.8l2.3 2z"/>',
    paw:     '<ellipse cx="7" cy="8.4" rx="2" ry="2.6"/><ellipse cx="12" cy="6.8" rx="2.1" ry="2.8"/><ellipse cx="17" cy="8.4" rx="2" ry="2.6"/><path d="M12 11.4c2.8 0 5.6 2.4 5.6 5 0 2-1.5 3.2-3.4 3.2-1 0-1.6-.3-2.2-.3s-1.2.3-2.2.3c-1.9 0-3.4-1.2-3.4-3.2 0-2.6 2.8-5 5.6-5z"/>',
    pickaxe: '<path d="M3.2 20.8a1.4 1.4 0 0 1 0-2l9-9 2 2-9 9a1.4 1.4 0 0 1-2 0z"/><path d="M13.5 3.2c2.8-1 6-.4 7.9 1.2l-1.5 1.5c-1.6-1-3.7-1.2-5.4-.4zM20.8 10.5c1-2.8.4-6-1.2-7.9l-1.5 1.5c1 1.6 1.2 3.7.4 5.4z"/>',
    anvil:   '<path d="M3 8h7.4c1 2 2.6 3 4.6 3h1.6c1.3 0 2.4-.8 3.4-2.4l1.7 1c-.8 2.2-2 3.7-3.6 4.4l1.3 2.6H6.6l1.5-2.8C5.6 13 3.9 11 3 8z"/><path d="M6 19h12v2H6z"/>',
    leaf:    '<path d="M20.4 3.6C11 3.6 5.6 7.4 4.4 13c-.5 2.4-.2 4.4.5 6l1.9-1.1c-.4-1.2-.6-2.6-.2-4.3.6-2.8 3-5.3 8.1-6.4-3.6 1.9-5.6 4.3-6.6 6.7-.5 1.2-.7 2.3-.7 3.3 6.6 1.5 11.6-2.2 12.8-8.2.4-2 .4-3.8.2-5.4z"/>',
    boot:    '<path d="M6 3h4.3v7.6c0 1.4.5 2.2 1.9 2.9l5.3 2.6c1.7.8 2.5 1.7 2.5 3.2V21H4v-2.2c1.3-.5 2-1.6 2-3.4z"/>',
    eye:     '<path fill-rule="evenodd" d="M12 5C6 5 2 12 2 12s4 7 10 7 10-7 10-7-4-7-10-7zm0 11a4 4 0 1 1 0-8 4 4 0 0 1 0 8zm0-6a2 2 0 1 0 0 4 2 2 0 0 0 0-4z"/>',
    pistol:  '<path d="M2.6 6h13.2l1.6-2h3.4l-1.4 3.4c.8.3 1.2.9 1.2 1.8 0 1.6-1.3 2.4-3.4 2.4h-3.5l-1.6 3.6c-.5 1.2-1.3 1.8-2.6 1.8H6.6l1.2-3.2c.3-.8.1-1.2-.7-1.6l-3.4-1.6C2.6 10 2 9.2 2 8.2V6z"/>',
    drop:    '<path d="M12 2.5S5.5 10.2 5.5 14.5a6.5 6.5 0 0 0 13 0C18.5 10.2 12 2.5 12 2.5z"/>',
    feather: '<path d="M19.6 3.2c-4.6-.7-8.9.8-11.4 3.9-2 2.4-2.6 5.3-2 8L3 18.3l1.5 1.5 3.2-3.2c2.7.6 5.6 0 8-2 3.1-2.5 4.6-6.8 3.9-11.4zM9.6 14.4l6.2-6.2-1-1-6.2 6.2a7.4 7.4 0 0 1 1-3.6c1.6-2 4.2-3.2 7.3-3.1.1 3.1-1.1 5.7-3.1 7.3a7.4 7.4 0 0 1-4.2 1z"/>',
};

const ICON_ALIAS = {
    '$': 'money', money: 'money', coins: 'money', coin: 'money', cash: 'money', dollar: 'money', sack: 'money',
    '★': 'star', '☆': 'star', star: 'star', law: 'star', rank: 'star', bounty: 'star',
    '☠': 'skull', skull: 'skull', danger: 'skull', death: 'skull', poison: 'skull',
    '🔔': 'bell', bell: 'bell', notify: 'bell', alert: 'bell',
    '🔥': 'fire', fire: 'fire', heat: 'fire',
    '♥': 'heart', heart: 'heart', revive: 'heart',
    '✚': 'cross', '➕': 'cross', '+': 'cross', cross: 'cross', medic: 'cross', plus: 'cross', heal: 'cross', health: 'cross',
    '⚑': 'flag', flag: 'flag', camp: 'flag',
    '🛡': 'shield', shield: 'shield', armor: 'shield',
    '⚠': 'warning', warning: 'warning', warn: 'warning', caution: 'warning',
    '✔': 'check', '✓': 'check', check: 'check', success: 'check', done: 'check', ok: 'check',
    '✖': 'x', '✗': 'x', '✕': 'x', x: 'x', close: 'x', error: 'x', fail: 'x', cancel: 'x',
    'ℹ': 'info', info: 'info',
    user: 'user', person: 'user',
    users: 'users', group: 'users', clan: 'users', gang: 'users', party: 'users', society: 'users',
    key: 'key',
    '🔒': 'lock', lock: 'lock', locked: 'lock', secure: 'lock',
    clock: 'clock', time: 'clock', cooldown: 'clock', timer: 'clock',
    bank: 'bank',
    '♠': 'spade', spade: 'spade', perk: 'spade', ability: 'spade',
    /* app/dashboard sidebar aliases */
    home: 'home', overview: 'home', dashboard: 'home', grid: 'home',
    medal: 'medal', rank2: 'medal', ranks: 'medal', badge: 'medal', award: 'medal',
    doc: 'doc', document: 'doc', paper: 'doc', bill: 'doc', bills: 'doc', invoice: 'doc', mail: 'doc',
    chart: 'chart', stats: 'chart', statistics: 'chart', graph: 'chart', report: 'chart',
    box: 'box', crate: 'box', order: 'box', orders: 'box', package: 'box', stock: 'box',
    coins: 'coins', ledger: 'coins', treasury: 'coins', wallet: 'coins',
    /* perk glyph aliases (pup-perks) */
    lungs: 'lungs', breath: 'lungs', stamina: 'lungs',
    hand: 'hand', grip: 'hand', steady: 'hand',
    paw: 'paw', animal: 'paw', hunt: 'paw', track: 'paw',
    pickaxe: 'pickaxe', pick: 'pickaxe', mine: 'pickaxe', dig: 'pickaxe',
    anvil: 'anvil', forge: 'anvil', craft: 'anvil', smith: 'anvil',
    leaf: 'leaf', herb: 'leaf', farm: 'leaf', gather: 'leaf',
    boot: 'boot', pack: 'boot', travel: 'boot',
    eye: 'eye', deadeye: 'eye', sight: 'eye', instinct: 'eye',
    pistol: 'pistol', gun: 'pistol', weapon: 'pistol', combat: 'pistol',
    drop: 'drop', water: 'drop', rain: 'drop', thirst: 'drop',
    feather: 'feather', bird: 'feather', falcon: 'feather', quill: 'feather',
};

function iconSVG(sym) {
    if (typeof sym !== 'string' || sym === '') return null;
    const key = ICON_ALIAS[sym] || (ICON_SVG[sym] ? sym : null);
    if (!key || !ICON_SVG[key]) return null;
    return `<svg class="pup-svg" viewBox="0 0 24 24" aria-hidden="true">${ICON_SVG[key]}</svg>`;
}

/* ====================================================================
   PERKS & PROGRESSION  (pup-perks)

   Loaded AFTER app.js, so it reuses that file's globals - iconSVG(), NUI(),
   DBG() - rather than duplicating them. Everything declared here is pk-*
   prefixed and every element id is pk-*, so this module cannot collide with
   any other panel.

   It owns no game state. The server sends a complete payload, this renders
   it, and clicks go back as intents. Nothing is applied optimistically: a
   perk shows as equipped only once the server has said so.
   ==================================================================== */

const pkWrap = document.getElementById('pk-wrap');

/* view state that must SURVIVE a server repaint (tab, search, selection) */
const pkState = {
    data: null,
    side: 'civ',    /* which progression you are looking at - each has its own
                       level, points and specialisation */
    cat: 'all',
    search: '',
    filter: 'all',
    sort: 'default',
    sel: null,      /* selected perk id - drives the detail panel */
    /* tree view flag: perks are ability cards, so nothing sets this true */
    tree: false,
    pending: null,  /* perk we sent an intent for; its buttons stay disabled until the repaint */
    guide: false,   /* the Guide panel is open */
};

/* does the server gate perks on level? When false, levels only hand out points
   and the panel must not show a requirement that is not real. */
function pkLevelsMatter() {
    return !!(pkState.data && pkState.data.requireLevels);
}

/* are unlocked perks automatically active (no loadout to manage)? */
function pkAutoEquip() {
    return !!(pkState.data && pkState.data.autoEquip);
}

/* the active side's progression block from the payload */
function pkSide() {
    const d = pkState.data;
    return (d && d.sides && d.sides[pkState.side]) || null;
}

/* has this side committed to a specialisation yet? */
function pkHasTree() {
    const s = pkSide();
    return !!(s && s.tree);
}

const PK_FILTERS = [
    ['all', 'All'], ['unlocked', 'Unlocked'], ['locked', 'Locked'],
    ['equipped', 'Equipped'], ['upgrade', 'Upgrade Available'], ['maxed', 'Maxed'],
];
const PK_SORTS = [
    ['default', 'Default'], ['name', 'Name'], ['level', 'Level Required'],
    ['category', 'Category'], ['progress', 'Progression'],
];

let pkPaintFilter = null;
let pkPaintSort = null;

function pkEl(id) { return document.getElementById(id); }

function pkIcon(name, cls) {
    const svg = iconSVG(name);
    const d = document.createElement('div');
    if (cls) d.className = cls;
    if (svg) d.innerHTML = svg;
    return d;
}

function pkEsc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, (c) =>
        ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function pkFindPerk(id) {
    return pkState.data ? pkState.data.perks.find((p) => p.id === id) : null;
}

/* ------------------------------------------------------------------ */
/* header: level, xp bar, points                                       */
/* ------------------------------------------------------------------ */

/* the HONEST WORK / OUTLAW switch. Each entry shows that side's specialisation
   and a dot when it has points waiting to be spent. */
function pkRenderSides() {
    const d = pkState.data;
    const host = pkEl('pk-sides');
    host.innerHTML = '';

    (d.sideOrder || ['civ', 'crime']).forEach((key) => {
        const s = d.sides && d.sides[key];
        if (!s) return;

        const el = document.createElement('div');
        el.className = 'pk-side'
            + (key === pkState.side ? ' active' : '')
            + (s.points > 0 ? ' has-points' : '');

        const dot = document.createElement('div');
        dot.className = 'pk-side-dot';
        el.appendChild(dot);

        const label = document.createElement('span');
        label.textContent = s.label;
        el.appendChild(label);

        const tree = document.createElement('span');
        tree.className = 'pk-side-tree';
        tree.textContent = s.treeLabel ? s.treeLabel : 'Unchosen';
        el.appendChild(tree);

        el.addEventListener('click', () => {
            if (pkState.side === key) return;
            pkState.side = key;
            pkState.sel = null;
            pkState.preview = null;   /* a path opened on the old side is not this one */
            pkState.cat = 'all';
            pkState.search = '';
            pkEl('pk-search').value = '';
            pkRenderAll(null);
        });
        host.appendChild(el);
    });
}

function pkRenderHeader(prev) {
    const d = pkState.data;
    const s = pkSide();
    const prevS = prev && prev.sides && prev.sides[pkState.side];
    const levelEl = pkEl('pk-level');
    const fill = pkEl('pk-xp-fill');
    const ghost = pkEl('pk-xp-ghost');
    const text = pkEl('pk-xp-text');

    pkRenderSides();
    if (!s) return;

    levelEl.textContent = s.level;

    /* width is a CSS transition, so assigning it animates the bar instead of
       snapping - no rAF loop and no timer to leak */
    const pct = (s.xpSpan && s.xpSpan > 0)
        ? Math.max(0, Math.min(100, (s.xpInto / s.xpSpan) * 100))
        : 100;

    if (prevS && prevS.level < s.level) {
        /* level up: run the old bar to full, then drop it and refill */
        fill.style.width = '100%';
        levelEl.classList.add('bump');
        setTimeout(() => levelEl.classList.remove('bump'), 320);
        setTimeout(() => {
            fill.style.transition = 'none';
            fill.style.width = '0%';
            requestAnimationFrame(() => {
                fill.style.transition = '';
                fill.style.width = pct + '%';
            });
        }, 400);
    } else {
        fill.style.width = pct + '%';
    }
    ghost.style.width = pct + '%';

    const left = document.createElement('span');
    left.textContent = s.xpToNext != null
        ? `${s.xpToNext.toLocaleString()} XP to level ${s.level + 1}`
        : 'Maximum level reached';
    const right = document.createElement('span');
    right.textContent = s.xpSpan != null
        ? `${s.xpInto.toLocaleString()} / ${s.xpSpan.toLocaleString()}`
        : `${s.xp.toLocaleString()} XP`;
    text.innerHTML = '';
    text.appendChild(left);
    text.appendChild(right);

    pkEl('pk-points-n').textContent = s.points;
    pkEl('pk-points').classList.toggle('has', s.points > 0);

    /* a reset is worth offering the moment there is ANYTHING to undo on either
       side - a committed specialisation counts, even with nothing bought */
    const anySpent = ((d.sides.civ && d.sides.civ.spent) || 0) + ((d.sides.crime && d.sides.crime.spent) || 0);
    const anyTree = !!((d.sides.civ && d.sides.civ.tree) || (d.sides.crime && d.sides.crime.tree));

    /* this button is the free weekly respec. The paid reset that also clears
       specialisations lives in the picker; switching a specialist starts from its root in the tree. */
    const r = (d.reset || {});
    const btn = pkEl('pk-reset');
    btn.textContent = r.ready ? 'Reset Perks (Free)' : `Reset in ${pkFmtLeft(r.inSeconds)}`;
    btn.classList.toggle('cooling', !r.ready);
    btn.classList.toggle('hidden', !(r.enabled && anySpent > 0));
}

/* the bar barely moves on a small gain, so the number is what the player
   actually reads - the bar is the slower, calmer signal */
function pkFlashGain(amount) {
    if (!pkState.data || pkWrap.classList.contains('hidden')) return;
    const text = pkEl('pk-xp-text');
    let tag = text.querySelector('.pk-gain');
    if (!tag) {
        tag = document.createElement('span');
        tag.className = 'pk-gain';
        text.appendChild(tag);
    }
    tag.textContent = `+${amount} XP`;
    requestAnimationFrame(() => tag.classList.add('show'));
    clearTimeout(tag._t);
    tag._t = setTimeout(() => tag.classList.remove('show'), 1800);
}

/* ------------------------------------------------------------------ */
/* sidebar                                                             */
/* ------------------------------------------------------------------ */

/* trees that belong to the side being viewed, plus the always-open ones */
function pkSideCats() {
    return (pkState.data.cats || []).filter((c) => c.side === pkState.side || c.always);
}

function pkRenderNav() {
    const host = pkEl('pk-nav-cats');
    host.innerHTML = '';

    /* nothing to navigate until a specialisation is picked */
    if (!pkHasTree()) {
        pkEl('pk-view-toggle').classList.add('hidden');
        return;
    }
    pkEl('pk-view-toggle').classList.remove('hidden');

    const cats = pkSideCats();
    const mine = cats.filter((c) => c.chosen || c.always);
    const gone = cats.filter((c) => !c.chosen && !c.always);

    const group = (title) => {
        const g = document.createElement('div');
        g.className = 'pk-nav-group';
        g.textContent = title;
        host.appendChild(g);
    };

    const row = (c, forgone) => {
        const el = document.createElement('div');
        el.className = 'pk-cat'
            + (!forgone && c.key === pkState.cat ? ' active' : '')
            + (forgone ? ' forgone' : '');
        el.appendChild(pkIcon(c.glyph, 'pk-cat-ico'));

        const label = document.createElement('div');
        label.className = 'pk-cat-label';
        label.textContent = c.label;
        el.appendChild(label);

        if (forgone) {
            /* switch control */
            el.appendChild(pkIcon('flag', 'pk-cat-lock'));
            el.classList.add('switchable');
            el.title = `Switch your ${pkSide().label.toLowerCase()} specialisation to ${c.label}`;
            const hint = document.createElement('div');
            hint.className = 'pk-cat-count';
            hint.textContent = 'Switch';
            el.appendChild(hint);
            el.addEventListener('click', () => pkSelectCat(c));
        } else {
            const count = document.createElement('div');
            count.className = 'pk-cat-count';
            count.textContent = `${c.owned}/${c.total}`;
            el.appendChild(count);
            el.addEventListener('click', () => {
                if (pkState.cat === c.key) return;
                pkState.cat = c.key;
                pkRenderNav();
                pkRenderBody();
            });
        }
        host.appendChild(el);
    };

    const allRow = {
        key: 'all', label: 'All', glyph: 'home',
        total: pkAllOnSide().length,
        owned: pkAllOnSide().filter((p) => p.owned).length,
    };
    row(allRow, false);
    mine.forEach((c) => row(c, false));

    if (gone.length) {
        /* the trees not taken are the switch targets */
        group('Switch specialisation');
        gone.forEach((c) => row(c, true));
    }

    /* no view toggle: the card collection is the only view */
    pkEl('pk-view-toggle').classList.add('hidden');
}

/* Every perk this side can actually reach: the chosen tree plus the open ones.
 * `includeUnchosen` widens it to the trees the character did not take, so the
 * tree view can still draw their roots (dimmed) as switch targets. */
function pkAllOnSide(includeUnchosen) {
    const keys = {};
    pkSideCats().forEach((c) => {
        if (c.chosen || c.always || includeUnchosen) keys[c.key] = true;
    });
    /* a special perk shows on its own side; one with no side shows on both */
    return pkState.data.perks.filter((p) =>
        keys[p.cat] && (p.side === pkState.side || (p.cat === 'special' && !p.side)));
}

/* ------------------------------------------------------------------ */
/* specialisation picker                                               */
/* ------------------------------------------------------------------ */

function pkRenderPicker() {
    const s = pkSide();
    const host = pkEl('pk-pick-cards');
    host.innerHTML = '';

    pkEl('pk-pick-sub').textContent =
        `Pick the ${s.label.toLowerCase()} path this character follows. `
        + 'Points earned on this side can only be spent on this side. '
        + 'You can change your mind later: the Guide explains how.';

    /* the rail is hidden while choosing, so the reset has to live down here -
       a player who committed on the OTHER side still needs a way back */
    const d = pkState.data;
    const anySpent = ((d.sides.civ && d.sides.civ.spent) || 0) + ((d.sides.crime && d.sides.crime.spent) || 0);
    const anyTree = !!((d.sides.civ && d.sides.civ.tree) || (d.sides.crime && d.sides.crime.tree));
    const foot = pkEl('pk-pick-foot');
    foot.classList.toggle('hidden', !(d.reset && d.reset.enabled && (anySpent > 0 || anyTree)));
    pkEl('pk-pick-reset').textContent = 'Full Reset';

    const options = (d.cats || []).filter((c) => c.side === pkState.side && !c.always);
    if (!options.length) {
        host.appendChild(pkIcon('lock', ''));
        return;
    }

    options.forEach((c) => {
        const el = document.createElement('div');
        el.className = 'pk-spec';
        el.appendChild(pkIcon(c.glyph, 'pk-spec-ico'));

        const name = document.createElement('div');
        name.className = 'pk-spec-name';
        name.textContent = c.label;

        const desc = document.createElement('div');
        desc.className = 'pk-spec-desc';
        desc.textContent = c.desc || '';

        const foot = document.createElement('div');
        foot.className = 'pk-spec-foot';
        foot.textContent = `${c.total} perk${c.total === 1 ? '' : 's'} / Read and choose`;

        el.appendChild(name);
        el.appendChild(desc);
        el.appendChild(foot);
        /* a card OPENS the tree rather than committing to it - nobody should
           have to guess what they are locking themselves into */
        el.addEventListener('click', () => {
            pkState.preview = c.key;
            pkRenderBody();
        });
        host.appendChild(el);
    });
}

/* ------------------------------------------------------------------ */
/* tree preview - everything the tree gives, before you commit         */
/* ------------------------------------------------------------------ */

function pkRenderPreview() {
    const d = pkState.data;
    const s = pkSide();
    const c = (d.cats || []).find((x) => x.key === pkState.preview);
    if (!c) { pkState.preview = null; pkRenderBody(); return; }

    pkEl('pk-preview-name').textContent = c.label;
    pkEl('pk-preview-desc').textContent = c.desc || '';
    /* the same page serves a first commitment and a look at another tree before
       switching to it; the button says which one this is */
    pkEl('pk-preview-commit').textContent = c.switchable
        ? `Switch to ${c.label}` : `Commit to ${c.label}`;
    pkEl('pk-preview-commit').classList.toggle('danger', !!c.switchable);

    const host = pkEl('pk-preview-list');
    host.innerHTML = '';

    const perks = d.perks.filter((p) => p.cat === c.key);
    let totalCost = 0;
    let topLevel = 0;

    perks.forEach((p) => {
        const row = document.createElement('div');
        row.className = 'pk-pv';
        row.appendChild(pkIcon(p.glyph, 'pk-pv-ico'));

        const body = document.createElement('div');
        body.className = 'pk-pv-body';

        const name = document.createElement('div');
        name.className = 'pk-pv-name';
        name.textContent = p.name;
        /* a perk gated behind another one is the tree's payoff - say so */
        if (p.reqPerkName) {
            const cap = document.createElement('span');
            cap.className = 'pk-pv-cap';
            cap.textContent = `after ${p.reqPerkName} ${p.reqPerkRank}`;
            name.appendChild(cap);
        }

        const desc = document.createElement('div');
        desc.className = 'pk-pv-desc';
        desc.textContent = p.desc || '';

        const tiers = document.createElement('div');
        tiers.className = 'pk-pv-tiers';
        (p.tiers || []).forEach((t) => {
            totalCost += t.cost;
            if (t.req > topLevel) topLevel = t.req;

            const tr = document.createElement('div');
            tr.className = 'pk-pv-tier';

            const n = document.createElement('div');
            n.className = 'pk-pv-tier-n';
            n.textContent = 'Rank ' + t.rank;

            const txt = document.createElement('div');
            txt.textContent = t.text || '';

            const cost = document.createElement('div');
            cost.className = 'pk-pv-tier-cost';
            cost.textContent = `${t.cost} pt${t.cost === 1 ? '' : 's'} / lvl ${t.req}`;

            tr.appendChild(n);
            tr.appendChild(txt);
            tr.appendChild(cost);
            tiers.appendChild(tr);
        });

        body.appendChild(name);
        body.appendChild(desc);
        body.appendChild(tiers);
        row.appendChild(body);
        host.appendChild(row);
    });

    const foot = document.createElement('div');
    foot.className = 'pk-pv-foot';
    const left = document.createElement('div');
    left.textContent = `${perks.length} perk${perks.length === 1 ? '' : 's'} / `
        + `${totalCost} points to max / reaches level ${topLevel}`;
    const right = document.createElement('div');
    /* on a switch preview the useful number is what leaving costs, not what
       you hold - the points cleared are NOT refunded */
    right.textContent = c.switchable
        ? `Switching clears the ${c.switchCost || 0} point${(c.switchCost || 0) === 1 ? '' : 's'} spent on this side and moves you from level ${c.switchLevel || 1} to level ${c.bankedLevel || 1}`
        : `You have ${s.points} ${s.label.toLowerCase()} point${s.points === 1 ? '' : 's'}`;
    foot.appendChild(left);
    foot.appendChild(right);
    host.appendChild(foot);
}

function pkConfirmTree(c, s) {
    pkModal({
        title: `Commit to ${c.label}?`,
        html:
            `<div>${pkEsc(c.desc || '')}</div>` +
            `<div class="pk-m-row"><span>This becomes your ${pkEsc(s.label.toLowerCase())} specialisation</span></div>` +
            '<div class="pk-m-cost">The other paths on this side close. You can switch later, but it costs you this tree.</div>',
        okLabel: 'Commit',
        onOk: () => {
            pkState.preview = null;
            NUI('perksChooseTree', { cat: c.key });
        },
    });
}

/* switching is not committing: warn about exactly what is lost and fire a
   different intent - the server clears only that side */
function pkConfirmSwitch(c, s) {
    const lostPts = c.switchCost || 0;
    const fromLvl = c.switchLevel || 1;
    const toLvl = c.bankedLevel || 1;
    pkModal({
        title: `Switch to ${c.label}?`,
        html:
            `<div>${pkEsc(c.desc || '')}</div>` +
            `<div class="pk-m-row warn"><span>${pkEsc(s.label)} level</span><b>${fromLvl} to ${toLvl}</b></div>` +
            `<div class="pk-m-row warn"><span>Points spent on this side cleared</span><b>${lostPts}</b></div>` +
            '<div class="pk-m-cost">Your level and points now follow the experience this specialisation has. ' +
            'Your other side keeps everything.</div>',
        okLabel: 'Switch',
        danger: true,
        onOk: () => {
            pkState.preview = null;
            NUI('perksSwitchTree', { cat: c.key });
        },
    });
}

/* clicking a specialisation (sidebar switch rows): commit, or PREVIEW first */
function pkSelectCat(c) {
    const s = pkSide();
    if (!c || !s) return;
    if (c.always || c.chosen) return;
    if (c.claimable)  { pkConfirmTree(c, s); return; }
    if (c.switchable) {
        /* open the full tree preview first; its Switch button leads to the confirm */
        pkState.preview = c.key;
        pkRenderBody();
    }
}

/* the free weekly respec keeps both specialists and every level, and only hands
   the invested points back. The countdown is display only - the server re-checks lastreset. */
function pkFmtLeft(sec) {
    sec = Math.max(0, Math.floor(sec || 0));
    const d = Math.floor(sec / 86400);
    const h = Math.floor((sec % 86400) / 3600);
    const m = Math.floor((sec % 3600) / 60);
    if (d > 0) return `${d} day${d === 1 ? '' : 's'}, ${h} hour${h === 1 ? '' : 's'}`;
    if (h > 0) return `${h} hour${h === 1 ? '' : 's'}, ${m} min`;
    return `${m} min`;
}

function pkConfirmWeeklyReset() {
    const r = (pkState.data && pkState.data.reset) || {};
    if (!r.enabled) return;

    if (!r.ready) {
        pkModal({
            title: 'Not yet',
            html:
                '<div>Your free perk reset is still on cooldown.</div>' +
                `<div class="pk-m-row"><span>Next reset available</span><b>${pkFmtLeft(r.inSeconds)}</b></div>` +
                `<div class="pk-m-cost">A free reset is available once every ${r.everyDays || 7} days.</div>`,
            okLabel: 'Close',
            noCancel: true,
        });
        return;
    }

    pkModal({
        title: 'Reset Perks?',
        html:
            '<div>Every point you have invested comes back, and you can spend them again however you like.</div>' +
            `<div class="pk-m-row"><span>You will receive</span><b>+${r.refund || 0} Perk Points</b></div>` +
            '<div class="pk-m-cost">Your specialisations, your levels and your XP are all unchanged. ' +
            `This is free, and available again in ${r.everyDays || 7} days.</div>`,
        okLabel: 'Reset Perks',
        danger: true,
        onOk: () => NUI('perksWeeklyReset', {}),
    });
}

/* ------------------------------------------------------------------ */
/* filtering + sorting                                                 */
/* ------------------------------------------------------------------ */

function pkVisiblePerks(includeUnchosen) {
    /* scoped to the side you are viewing and the trees it can reach */
    let list = pkAllOnSide(includeUnchosen);

    if (pkState.cat !== 'all') list = list.filter((p) => p.cat === pkState.cat);

    const q = pkState.search.trim().toLowerCase();
    if (q) {
        list = list.filter((p) =>
            (p.name || '').toLowerCase().includes(q) ||
            (p.desc || '').toLowerCase().includes(q) ||
            (p.current || '').toLowerCase().includes(q) ||
            (p.nextText || '').toLowerCase().includes(q));
    }

    switch (pkState.filter) {
        case 'unlocked': list = list.filter((p) => p.owned); break;
        case 'locked':   list = list.filter((p) => !p.owned); break;
        case 'equipped': list = list.filter((p) => p.equipped); break;
        case 'upgrade':  list = list.filter((p) => p.canBuy); break;
        case 'maxed':    list = list.filter((p) => p.maxed); break;
        default: break;
    }

    const byName = (a, b) => (a.name || '').localeCompare(b.name || '');
    switch (pkState.sort) {
        case 'name':     list.sort(byName); break;
        case 'level':    list.sort((a, b) => (a.req - b.req) || byName(a, b)); break;
        case 'category': list.sort((a, b) => (a.cat || '').localeCompare(b.cat || '') || byName(a, b)); break;
        case 'progress': list.sort((a, b) => (b.rank / b.maxRank) - (a.rank / a.maxRank) || byName(a, b)); break;
        default:
            /* default surfaces what the player can act on, then what they own */
            list.sort((a, b) => {
                const score = (p) => (p.canBuy ? 0 : p.equipped ? 1 : p.owned ? 2 : p.locked ? 4 : 3);
                return score(a) - score(b) || byName(a, b);
            });
    }
    return list;
}

/* ------------------------------------------------------------------ */
/* cards                                                               */
/* ------------------------------------------------------------------ */

function pkStatusOf(p) {
    if (p.locked)   return ['locked',   `Requires Level ${p.req}`];
    if (p.equipped) return ['equipped', 'Equipped'];
    if (p.maxed)    return ['maxed',    'Maxed'];
    if (p.canBuy)   return ['upgrade',  p.owned ? 'Upgrade' : 'Unlock'];
    if (p.owned)    return ['',         'Unlocked'];
    return ['locked', p.blocked || 'Locked'];
}

/* an ability card: art plate on top, body underneath, level shown as pips.
   States: locked, owned, equipped, maxed, upgrade. */
function pkCard(p) {
    const [cls, label] = pkStatusOf(p);

    const el = document.createElement('div');
    el.className = 'pk-card'
        + (p.locked ? ' locked' : '')
        + (p.owned && !p.locked ? ' owned' : '')
        + (p.equipped ? ' equipped' : '')
        + (p.maxed ? ' maxed' : '')
        + (p.canBuy ? ' upgrade' : '')
        + (p.slot === 'special' ? ' special' : '')
        + (pkState.sel === p.id ? ' sel' : '');
    el.dataset.id = p.id;

    /* the art plate - the card's face */
    const art = document.createElement('div');
    art.className = 'pk-card-art';
    const ico = pkIcon(p.locked ? 'lock' : p.glyph, '');
    if (ico) art.appendChild(ico);
    el.appendChild(art);

    const body = document.createElement('div');
    body.className = 'pk-card-body';

    const name = document.createElement('div');
    name.className = 'pk-card-name';
    name.textContent = p.name;
    body.appendChild(name);

    const cat = document.createElement('div');
    cat.className = 'pk-card-cat';
    cat.textContent = (p.slot === 'special' ? 'Signature - ' : '') + (p.sideLabel || '');
    body.appendChild(cat);

    const pips = document.createElement('div');
    pips.className = 'pk-card-pips';
    for (let i = 1; i <= p.maxRank; i++) {
        const pip = document.createElement('div');
        pip.className = 'pk-pip' + (i <= p.rank ? ' on' : '');
        pips.appendChild(pip);
    }
    body.appendChild(pips);
    el.appendChild(body);

    /* the state, named in the corner rather than as another line of body text */
    const tag = document.createElement('div');
    tag.className = 'pk-card-tag';
    tag.textContent = p.equipped ? 'Equipped' : label;
    el.appendChild(tag);

    el.addEventListener('click', () => pkSelect(p.id));
    el.addEventListener('mouseenter', (e) => pkTipShow(p, e.currentTarget));
    el.addEventListener('mouseleave', pkTipHide);
    return el;
}

function pkShowEmpty(title, sub) {
    const empty = pkEl('pk-empty');
    empty.classList.remove('hidden');
    empty.innerHTML = '';
    const t = document.createElement('div');
    t.textContent = title;
    empty.appendChild(t);
    if (sub) {
        const s = document.createElement('div');
        s.className = 'pk-empty-sub';
        s.textContent = sub;
        empty.appendChild(s);
    }
}

function pkRenderGrid() {
    const grid = pkEl('pk-grid');
    grid.innerHTML = '';

    const list = pkVisiblePerks();
    if (!list.length) {
        grid.classList.add('hidden');
        const searching = pkState.search.trim() !== '';
        pkShowEmpty(
            searching ? 'No perks match your search.' : 'No perks here yet.',
            searching ? 'Try a different word, or clear the filter.'
                      : 'Try another category or clear the filter.');
        return;
    }
    grid.classList.remove('hidden');
    pkEl('pk-empty').classList.add('hidden');
    list.forEach((p) => grid.appendChild(pkCard(p)));
}

/* ------------------------------------------------------------------ */
/* tree view                                                           */
/*                                                                     */
/* Edges come from an OPTIONAL `parent` field on a perk in the          */
/* pup-perks config. With no parents set, each category renders as one  */
/* chain in unlock order - which is the truth today. Add                */
/* `parent = '<perkid>'` server-side and this branches on its own;      */
/* nothing in here needs to change.                                     */
/* ------------------------------------------------------------------ */

function pkRenderTree() {
    const host = pkEl('pk-tree-nodes');
    const svg = pkEl('pk-tree-links');
    host.innerHTML = '';
    svg.innerHTML = '';

    /* your tree only (plus the always-open ones); switching starts from the sidebar */
    const list = pkVisiblePerks();
    if (!list.length) {
        pkEl('pk-tree').classList.add('hidden');
        pkShowEmpty('No perks match your search.', 'Try a different word, or clear the filter.');
        return;
    }
    pkEl('pk-empty').classList.add('hidden');
    pkEl('pk-tree').classList.remove('hidden');

    /* ================================================================
       Tree: each perk is a branch under its specialist root and each level is
       its own node. Filled = bought, ringed = buyable now, hollow = locked,
       and a branch dims when the perk is out of reach. Real prerequisites
       (p.parent) draw a link between branches.
       ================================================================ */
    const cats = pkSideCats();
    const byCat = {};
    list.forEach((p) => { (byCat[p.cat] = byCat[p.cat] || []).push(p); });

    const edges = [];
    const nodeEls = {};   /* perk id -> its FIRST level node (link lands here) */
    const tailEls = {};   /* perk id -> its LAST level node  (link leaves here) */
    const rootEls = {};   /* cat key -> the specialist root node */

    cats.forEach((cat) => {
        const perks = byCat[cat.key];
        if (!perks || !perks.length) return;
        perks.sort((a, b) => (a.req - b.req) || (a.name || '').localeCompare(b.name || ''));

        const group = document.createElement('div');
        group.className = 'pk-treegroup'
            + (cat.chosen ? ' chosen' : '')
            + (cat.always ? ' always' : '');

        /* the specialist itself is the root of its tree */
        const root = document.createElement('div');
        root.className = 'pk-root' + (cat.chosen ? ' chosen' : '');
        const rico = iconSVG(cat.glyph);
        root.innerHTML =
            (rico || '') +
            `<div class="pk-root-name">${pkEsc(cat.label)}</div>` +
            `<div class="pk-root-tag">${cat.chosen ? 'YOUR SPECIALIST' : cat.always ? 'OPEN TO ALL' : 'NOT CHOSEN'}</div>`;
        root.addEventListener('click', () => pkSelectCat(cat));
        group.appendChild(root);
        rootEls[cat.key] = root;

        /* depth from prerequisites: a perk with no parent is row 0, anything else
           sits one row below what it needs. Guarded so a bad config
           (a -> b -> a) cannot loop forever. */
        const byId = {};
        perks.forEach((p) => { byId[p.id] = p; });
        const depthOf = (p, seen) => {
            if (!p.parent || !byId[p.parent]) return 0;
            seen = seen || {};
            if (seen[p.id]) return 0;
            seen[p.id] = true;
            return 1 + depthOf(byId[p.parent], seen);
        };
        const rows = [];
        perks.forEach((p) => {
            const d = depthOf(p);
            (rows[d] = rows[d] || []).push(p);
        });

        const branches = document.createElement('div');
        branches.className = 'pk-branches rows';

        /* one horizontal row per depth, so children sit UNDER what they need */
        const rowHosts = rows.map(() => {
            const rh = document.createElement('div');
            rh.className = 'pk-branchrow';
            branches.appendChild(rh);
            return rh;
        });

        rows.forEach((rowPerks, depth) => {
        rowPerks.forEach((p) => {
            const branch = document.createElement('div');
            branch.className = 'pk-branch'
                + (p.locked ? ' locked' : '')
                + (pkState.sel === p.id ? ' sel' : '');
            branch.dataset.id = p.id;

            const head = document.createElement('div');
            head.className = 'pk-branch-head';
            const ico = iconSVG(p.glyph);
            head.innerHTML =
                (ico || '') +
                `<div class="pk-branch-name">${pkEsc(p.name)}</div>` +
                `<div class="pk-branch-rank">${p.rank}/${p.maxRank}</div>`;
            branch.appendChild(head);

            /* one node per level */
            const ladder = document.createElement('div');
            ladder.className = 'pk-ladder';

            const tiers = p.tiers || [];
            for (let i = 1; i <= p.maxRank; i++) {
                const t = tiers[i - 1] || {};

                /* the four node states */
                let state = 'locked';
                if (i <= p.rank)                    state = (i === p.maxRank) ? 'maxed' : 'active';
                else if (i === p.rank + 1 && p.canBuy) state = 'avail';

                if (i > 1) {
                    const stem = document.createElement('div');
                    stem.className = 'pk-stem' + (i <= p.rank ? ' on' : '');
                    ladder.appendChild(stem);
                }

                const lvl = document.createElement('div');
                lvl.className = `pk-lvl ${state}`;
                lvl.dataset.id = p.id;
                lvl.dataset.lvl = String(i);
                lvl.innerHTML = `<span class="pk-lvl-n">${i}</span>`;

                /* the requirement is on the node itself, so a player can read
                   the gate without having to click anything */
                /* every node shows its price, locked ones too, so a player can read the
                   whole ladder. `t.req` only shows when the server enforces levels. */
                const meta = document.createElement('div');
                meta.className = 'pk-lvl-meta';
                const cost = `${t.cost || 1} pt`;
                if (pkLevelsMatter() && state === 'locked' && t.req) meta.textContent = `Lv ${t.req}`;
                else if (state !== 'active' && state !== 'maxed')    meta.textContent = cost;
                lvl.appendChild(meta);

                lvl.addEventListener('click', (e) => { e.stopPropagation(); pkSelect(p.id); });
                lvl.addEventListener('mouseenter', (e) => { pkTipShow(p, e.currentTarget); pkHighlightPath(p.id, true); });
                lvl.addEventListener('mouseleave', () => { pkTipHide(); pkHighlightPath(p.id, false); });

                ladder.appendChild(lvl);
                /* first node = where an incoming branch lands, last = where an
                   outgoing branch leaves from */
                if (i === 1) nodeEls[p.id] = lvl;
                if (i === p.maxRank) tailEls[p.id] = lvl;
            }

            branch.appendChild(ladder);
            branch.addEventListener('click', () => pkSelect(p.id));
            rowHosts[depth].appendChild(branch);

            /* a prerequisite is the branch: parent's LAST node -> child's FIRST */
            if (p.parent) edges.push([p.parent, p.id, p.owned]);
        });
        });

        group.appendChild(branches);
        host.appendChild(group);
    });

    /* lines are drawn AFTER layout, from real measured positions, so they hold
       at any resolution or browser zoom */
    requestAnimationFrame(() => {
        const box = svg.getBoundingClientRect();
        if (!box.width) return;
        svg.setAttribute('viewBox', `0 0 ${box.width} ${box.height}`);
        /* right-angle dashed connectors, from the parent's LAST level node to the
           child's FIRST, so the line starts where the prerequisite is satisfied */
        edges.forEach(([from, to, on]) => {
            const a = tailEls[from] || nodeEls[from];
            const b = nodeEls[to];
            if (!a || !b) return;
            const ra = a.getBoundingClientRect();
            const rb = b.getBoundingClientRect();

            const x1 = ra.left + ra.width / 2 - box.left;
            const y1 = ra.bottom - box.top;
            const x2 = rb.left + rb.width / 2 - box.left;
            const y2 = rb.top - box.top;
            const mid = y1 + Math.max(6, (y2 - y1) / 2);

            const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            path.setAttribute('d', `M ${x1} ${y1} V ${mid} H ${x2} V ${y2}`);
            path.setAttribute('fill', 'none');
            path.dataset.from = from;
            path.dataset.to = to;
            if (on) path.classList.add('on');
            svg.appendChild(path);
        });
    });
}

function pkHighlightPath(id, on) {
    /* connectors are <path> elbows, not <line> */
    pkEl('pk-tree-links').querySelectorAll('path').forEach((l) => {
        if (l.dataset.from === id || l.dataset.to === id) l.classList.toggle('warm', on);
    });
}

function pkRenderBody() {
    const picking = !pkHasTree();

    /* the picker REPLACES the perks: there is nothing to spend on until this
       side has a specialisation. .picking also drops the nav rail, which would
       otherwise sit there empty and push the cards off-centre. */
    /* the full-page preview serves both picking and switching; only the button
       at its top leads on to the switch confirm */
    const previewing = !!pkState.preview;

    pkEl('pk-body').classList.toggle('picking', picking || previewing);
    pkEl('pk-pick').classList.toggle('hidden', !picking || previewing);
    pkEl('pk-preview').classList.toggle('hidden', !previewing);
    pkEl('pk-toolbar').classList.toggle('hidden', picking || previewing);
    if (picking || previewing) {
        pkEl('pk-grid').classList.add('hidden');
        pkEl('pk-tree').classList.add('hidden');
        pkEl('pk-empty').classList.add('hidden');
        pkEl('pk-detail').classList.add('hidden');
        if (previewing) pkRenderPreview(); else pkRenderPicker();
        return;
    }

    if (pkState.tree) {
        pkEl('pk-grid').classList.add('hidden');
        pkRenderTree();
    } else {
        pkEl('pk-tree').classList.add('hidden');
        pkRenderGrid();
    }
}

/* ------------------------------------------------------------------ */
/* detail panel                                                        */
/* ------------------------------------------------------------------ */

function pkSelect(id) {
    pkState.sel = (pkState.sel === id) ? null : id;
    if (pkState.sel && pkState.guide) { pkState.guide = false; pkRenderGuide(); }
    /* only the selection changed - repaint the selected class and the detail
       panel, not the whole grid */
    document.querySelectorAll('#pk-grid .pk-card, #pk-tree .pk-node').forEach((el) => {
        el.classList.toggle('sel', el.dataset.id === pkState.sel);
    });
    pkRenderDetail();
}

function pkBlock(label, value, dim) {
    const b = document.createElement('div');
    b.className = 'pk-d-block';
    const l = document.createElement('div');
    l.className = 'pk-d-label';
    l.textContent = label;
    const v = document.createElement('div');
    v.className = 'pk-d-value' + (dim ? ' dim' : '');
    v.textContent = value;
    b.appendChild(l);
    b.appendChild(v);
    return b;
}

function pkReqRow(ok, text) {
    const r = document.createElement('div');
    r.className = 'pk-d-req ' + (ok ? 'ok' : 'no');
    const svg = iconSVG(ok ? 'check' : 'x');
    if (svg) {
        const holder = document.createElement('span');
        holder.innerHTML = svg;
        if (holder.firstChild) r.appendChild(holder.firstChild);
    }
    const t = document.createElement('span');
    t.textContent = text;
    r.appendChild(t);
    return r;
}

function pkHint(text) {
    const el = document.createElement('div');
    el.className = 'pk-d-value dim pk-d-hint';
    el.textContent = text;
    return el;
}

function pkRenderDetail() {
    const host = pkEl('pk-detail');
    const p = pkFindPerk(pkState.sel);
    if (!p) {
        host.classList.add('hidden');
        host.innerHTML = '';
        return;
    }

    const d = pkState.data;
    host.innerHTML = '';
    host.classList.remove('hidden');

    const scroll = document.createElement('div');
    scroll.className = 'pk-d-scroll';

    const head = document.createElement('div');
    head.className = 'pk-d-head';
    head.appendChild(pkIcon(p.glyph, 'pk-d-ico'));

    const nm = document.createElement('div');
    nm.className = 'pk-d-name';
    nm.textContent = p.name;

    const catRow = (d.cats || []).find((c) => c.key === p.cat);
    const cat = document.createElement('div');
    cat.className = 'pk-d-cat';
    /* name the pool that pays, not just the tree - it is the thing players
       most often get wrong once there are two of them */
    cat.textContent = (catRow ? catRow.label : (p.cat || ''))
        + (p.sideLabel ? ' / ' + p.sideLabel : '');

    const desc = document.createElement('div');
    desc.className = 'pk-d-desc';
    desc.textContent = p.desc || '';

    head.appendChild(nm);
    head.appendChild(cat);
    head.appendChild(desc);
    scroll.appendChild(head);

    const rule = () => {
        const r = document.createElement('div');
        r.className = 'pk-d-rule';
        return r;
    };

    scroll.appendChild(rule());
    scroll.appendChild(pkBlock('Current Level', `${p.rank} / ${p.maxRank}`));
    scroll.appendChild(pkBlock('Current Effect', p.current || 'Not unlocked yet', !p.current));

    if (!p.maxed) {
        scroll.appendChild(pkBlock(p.owned ? 'Next Level' : 'Unlocks', p.nextText || '-'));
        scroll.appendChild(rule());

        const reqs = document.createElement('div');
        reqs.className = 'pk-d-block';
        const rl = document.createElement('div');
        rl.className = 'pk-d-label';
        rl.textContent = 'Requirements';
        reqs.appendChild(rl);
        /* a prerequisite perk comes first - it is the hardest one to satisfy */
        if (p.reqPerkName) {
            reqs.appendChild(pkReqRow(!!p.reqPerkOk,
                `${p.reqPerkName} at rank ${p.reqPerkRank}`));
        }
        /* both requirements are read off the perk's OWN side, which is not
           always the side being viewed (Special perks sit on either) */
        const ps = (d.sides && d.sides[p.side]) || pkSide() || { level: 0, points: 0, label: '' };
        reqs.appendChild(pkReqRow(ps.level >= p.nextReq,
            `${ps.label} level ${p.nextReq}`));
        reqs.appendChild(pkReqRow(ps.points >= p.nextCost,
            `${p.nextCost} ${ps.label.toLowerCase()} point${p.nextCost === 1 ? '' : 's'}`));
        scroll.appendChild(reqs);
    } else {
        scroll.appendChild(rule());
        scroll.appendChild(pkBlock('Status', 'Maximum level reached'));
    }

    host.appendChild(scroll);

    const actions = document.createElement('div');
    actions.className = 'pk-d-actions';
    const busy = pkState.pending === p.id;

    if (!p.maxed) {
        const can = p.canBuy && !busy;
        const up = document.createElement('div');
        up.className = 'pk-btn' + (can ? '' : ' disabled');
        up.textContent = busy ? 'Working...' : (p.owned ? 'Upgrade' : 'Unlock');
        if (can) up.addEventListener('click', () => pkConfirmUpgrade(p));
        actions.appendChild(up);
        if (!p.canBuy && p.blocked) actions.appendChild(pkHint(p.blocked));
    }

    /* no Equip button and no slot warning in auto-equip mode - buying a
       rank is what turns a perk on */
    if (p.owned && !pkAutoEquip()) {
        const slotsFree = (d.slots || []).some((s) => s.state === 'empty');
        const can = !busy && (p.equipped || slotsFree);
        const eq = document.createElement('div');
        eq.className = 'pk-btn ghost' + (can ? '' : ' disabled');
        eq.textContent = p.equipped ? 'Unequip' : 'Equip';
        if (can) {
            eq.addEventListener('click', () => {
                pkState.pending = p.id;
                pkRenderDetail();
                NUI('perksEquip', { id: p.id });
            });
        }
        actions.appendChild(eq);
        if (!p.equipped && !slotsFree) {
            actions.appendChild(pkHint('No available slots. Unequip another perk to equip this one.'));
        }
    }

    host.appendChild(actions);
}

/* ------------------------------------------------------------------ */
/* guide                                                               */
/* The words come from config/guide.lua and arrive with the payload,   */
/* with the real numbers already filled in. Everything goes in as text. */
/* ------------------------------------------------------------------ */

function pkDiv(cls, text) {
    const d = document.createElement('div');
    d.className = cls;
    if (text !== undefined && text !== null) d.textContent = text;
    return d;
}

function pkResetCard(info, status, action) {
    const card = pkDiv('pk-g-opt');
    const head = pkDiv('pk-g-opt-head');
    head.appendChild(pkDiv('pk-g-opt-name', info.name));
    head.appendChild(pkDiv('pk-g-opt-cost', info.cost));
    card.appendChild(head);
    if (info.does) card.appendChild(pkDiv('pk-g-text', info.does));
    if (info.keeps) card.appendChild(pkDiv('pk-g-text keep', info.keeps));
    if (info.how) card.appendChild(pkDiv('pk-g-text', info.how));
    if (status) card.appendChild(pkDiv('pk-g-status', status));
    if (action) {
        const btn = pkDiv('pk-btn' + (action.danger ? ' danger' : '') + (action.onClick ? '' : ' disabled'), action.label);
        if (action.onClick) btn.addEventListener('click', action.onClick);
        card.appendChild(btn);
    }
    return card;
}

function pkRenderResets(host, resets) {
    const d = pkState.data;
    const r = d.reset || {};
    if (!r.enabled) {
        host.appendChild(pkDiv('pk-g-text', 'Perk resets are turned off on this server.'));
        return;
    }
    const spent = ((d.sides.civ && d.sides.civ.spent) || 0) + ((d.sides.crime && d.sides.crime.spent) || 0);
    const anyTree = !!((d.sides.civ && d.sides.civ.tree) || (d.sides.crime && d.sides.crime.tree));

    if (resets.free) {
        let status, action;
        if (!r.ready) {
            status = `Available again in ${pkFmtLeft(r.inSeconds)}`;
            action = { label: 'On Cooldown' };
        } else if (spent <= 0) {
            status = 'You have not spent any points yet.';
            action = { label: 'Nothing to Reset' };
        } else {
            status = `Ready now. You would get back ${r.refund || 0} point${r.refund === 1 ? '' : 's'}.`;
            action = { label: 'Use Free Reset', onClick: pkConfirmWeeklyReset };
        }
        host.appendChild(pkResetCard(resets.free, status, action));
    }
    if (resets.switch) host.appendChild(pkResetCard(resets.switch));
    if (resets.full) {
        const ok = spent > 0 || anyTree;
        host.appendChild(pkResetCard(resets.full, null,
            ok ? { label: 'Full Reset', danger: true, onClick: pkConfirmReset } : { label: 'Nothing to Reset' }));
    }
}

function pkRenderGuide() {
    const host = pkEl('pk-guide');
    const btn = pkEl('pk-guide-btn');
    const guide = pkState.data && pkState.data.guide;
    btn.classList.toggle('hidden', !guide);
    btn.classList.toggle('on', !!pkState.guide);
    const scrollWas = host.firstChild ? host.firstChild.scrollTop : 0;
    host.innerHTML = '';
    if (!guide || !pkState.guide) {
        host.classList.add('hidden');
        return;
    }
    host.classList.remove('hidden');

    const scroll = pkDiv('pk-g-scroll');
    (guide.sections || []).forEach((sec) => {
        const box = pkDiv('pk-g-sec');
        const head = pkDiv('pk-g-head');
        head.appendChild(pkIcon(sec.glyph, 'pk-g-ico'));
        head.appendChild(pkDiv('pk-g-title', sec.title));
        box.appendChild(head);
        (sec.steps || []).forEach((step, i) => {
            const row = pkDiv('pk-g-step');
            row.appendChild(pkDiv('pk-g-step-n', String(i + 1)));
            row.appendChild(pkDiv('pk-g-text', step));
            box.appendChild(row);
        });
        (sec.text || []).forEach((t) => box.appendChild(pkDiv('pk-g-text', t)));
        (sec.list || []).forEach((item) => {
            const row = pkDiv('pk-g-row');
            row.appendChild(pkDiv('pk-g-row-label', item.label));
            row.appendChild(pkDiv('pk-g-text', item.text));
            box.appendChild(row);
        });
        if (sec.resets) pkRenderResets(box, sec.resets);
        scroll.appendChild(box);
    });
    host.appendChild(scroll);
    scroll.scrollTop = scrollWas; /* a repaint must not throw the reader back to the top */
}

function pkToggleGuide() {
    pkState.guide = !pkState.guide;
    if (pkState.guide && pkState.sel) {
        pkState.sel = null;
        document.querySelectorAll('#pk-grid .pk-card.sel').forEach((el) => el.classList.remove('sel'));
        pkRenderDetail();
    }
    pkRenderGuide();
}

/* open by itself the first time this player ever opens the menu. Only a convenience:
   if the browser forgets, the guide opens once more and nothing else changes. */
function pkFirstVisit() {
    try {
        if (window.localStorage.getItem('pkGuideSeen')) return false;
        window.localStorage.setItem('pkGuideSeen', '1');
        return true;
    } catch (e) {
        return false;
    }
}

/* ------------------------------------------------------------------ */
/* equipped slots                                                      */
/* ------------------------------------------------------------------ */

function pkRenderSlots(prev) {
    const row = pkEl('pk-slots-row');
    row.innerHTML = '';

    const slots = pkState.data.slots || [];

    /* auto-equip mode: no slots to fill, so this row lists everything currently
       active. Nothing here is clickable. */
    if (pkAutoEquip()) {
        pkEl('pk-slots-label').textContent = 'Active';
        /* `auto` lets a long row of chips wrap and scroll */
        row.classList.add('auto');
        if (!slots.length) {
            const t = document.createElement('div');
            t.className = 'pk-slot empty';
            t.innerHTML = '<div class="pk-slot-name">No perks yet</div>';
            row.appendChild(t);
        }
        slots.forEach((s) => {
            const el = document.createElement('div');
            el.className = 'pk-slot filled';
            el.appendChild(pkIcon(s.glyph, ''));
            const t = document.createElement('div');
            t.className = 'pk-slot-name';
            t.textContent = s.maxRank > 1 ? `${s.name} ${s.rank}/${s.maxRank}` : s.name;
            el.appendChild(t);
            el.title = 'Active automatically';
            row.appendChild(el);
        });
        pkEl('pk-slots-count').textContent =
            `${slots.length} perk${slots.length === 1 ? '' : 's'} active`;
        return;
    }

    /* ================================================================
       The ability loadout: one SPECIAL slot and three PASSIVE ones.
       Empty slots are shown; clicking a filled slot takes that card off
       (the server decides).
       ================================================================ */
    pkEl('pk-slots-label').textContent = 'Loadout';
    row.classList.remove('auto');
    row.classList.add('loadout');

    const bySpecial = slots.filter((s) => s.kind === 'special');
    const byPassive = slots.filter((s) => s.kind !== 'special');
    let filled = 0;

    const slotEl = (s) => {
        const el = document.createElement('div');
        el.className = 'pk-slot ' + (s.state === 'filled' ? 'filled' : 'empty')
            + (s.kind === 'special' ? ' special' : '');

        if (s.state === 'filled') {
            filled++;
            el.appendChild(pkIcon(s.glyph, ''));
            const t = document.createElement('div');
            t.className = 'pk-slot-name';
            t.textContent = s.name;
            el.appendChild(t);
            const lv = document.createElement('div');
            lv.className = 'pk-slot-lv';
            lv.textContent = `${s.rank}/${s.maxRank}`;
            el.appendChild(lv);
            el.title = 'Click to unequip';
            el.addEventListener('click', () => {
                pkState.pending = s.id;
                pkRenderDetail();
                NUI('perksEquip', { id: s.id });
            });
        } else {
            const t = document.createElement('div');
            t.className = 'pk-slot-name';
            t.textContent = s.kind === 'special' ? 'No signature card' : 'Empty';
            el.appendChild(t);
        }
        return el;
    };

    if (bySpecial.length) {
        const head = document.createElement('div');
        head.className = 'pk-slot-kind';
        head.textContent = 'Signature';
        row.appendChild(head);
        bySpecial.forEach((s) => row.appendChild(slotEl(s)));
    }
    if (byPassive.length) {
        const head = document.createElement('div');
        head.className = 'pk-slot-kind';
        head.textContent = 'Passive';
        row.appendChild(head);
        byPassive.forEach((s) => row.appendChild(slotEl(s)));
    }

    pkEl('pk-slots-count').textContent = `${filled} / ${slots.length} Equipped`;
    return;
}

/* slots are typed and always available; the function name is kept for its callers */
function pkRenderSlotsLegacy(prev) {
    const row = pkEl('pk-slots-row');
    const slots = pkState.data.slots || [];
    let used = 0;
    let unlocked = 0;

    slots.forEach((s, i) => {
        const el = document.createElement('div');
        el.className = 'pk-slot ' + s.state;

        if (s.state === 'locked') {
            el.appendChild(pkIcon('lock', ''));
            const t = document.createElement('div');
            t.className = 'pk-slot-name';
            t.textContent = `Level ${s.req}`;
            el.appendChild(t);
        } else if (s.state === 'filled') {
            unlocked++; used++;
            el.appendChild(pkIcon(s.glyph, ''));
            const t = document.createElement('div');
            t.className = 'pk-slot-name';
            t.textContent = s.name;
            el.appendChild(t);
            el.title = 'Click to unequip';
            el.addEventListener('click', () => {
                pkState.pending = s.id;
                pkRenderDetail();
                NUI('perksEquip', { id: s.id });
            });
            /* a slot that just changed hands gets a small pop, nothing more */
            const before = prev && prev.slots && prev.slots[i];
            if (before && before.id !== s.id) el.classList.add('pop');
        } else {
            unlocked++;
            const t = document.createElement('div');
            t.className = 'pk-slot-name';
            t.textContent = 'Empty';
            el.appendChild(t);
        }
        row.appendChild(el);
    });

    pkEl('pk-slots-count').textContent = `${used} / ${unlocked} Slots`;
}

/* ------------------------------------------------------------------ */
/* dropdowns                                                           */
/* ------------------------------------------------------------------ */

function pkBuildSelect(id, options, getCur, onPick) {
    const host = pkEl(id);
    const menu = host.querySelector('.pk-select-menu');
    const btnLabel = host.querySelector('.pk-select-btn span');

    const paint = () => {
        const cur = getCur();
        const found = options.find(([k]) => k === cur);
        btnLabel.textContent = found ? found[1] : cur;
        menu.querySelectorAll('.pk-opt').forEach((o) => o.classList.toggle('on', o.dataset.k === cur));
    };

    menu.innerHTML = '';
    options.forEach(([k, label]) => {
        const o = document.createElement('div');
        o.className = 'pk-opt';
        o.dataset.k = k;
        o.textContent = label;
        o.addEventListener('click', (e) => {
            e.stopPropagation();
            host.classList.remove('open');
            onPick(k);
            paint();
        });
        menu.appendChild(o);
    });

    host.querySelector('.pk-select-btn').addEventListener('click', (e) => {
        e.stopPropagation();
        const wasOpen = host.classList.contains('open');
        document.querySelectorAll('#pk-wrap .pk-select').forEach((s) => s.classList.remove('open'));
        host.classList.toggle('open', !wasOpen);
    });

    paint();
    return paint;
}

/* ------------------------------------------------------------------ */
/* modal                                                               */
/* ------------------------------------------------------------------ */

function pkModal(opts) {
    pkEl('pk-modal-title').textContent = opts.title || '';

    const body = pkEl('pk-modal-body');
    body.innerHTML = '';
    if (opts.html) body.innerHTML = opts.html;
    else if (opts.text) body.textContent = opts.text;

    /* replaceWith(clone) drops every previous listener - a modal reopened ten
       times must not fire its action ten times */
    const ok = pkEl('pk-modal-ok').cloneNode(true);
    const cancel = pkEl('pk-modal-cancel').cloneNode(true);
    ok.textContent = opts.okLabel || 'Confirm';
    ok.className = 'pk-btn' + (opts.danger ? ' danger' : '');
    cancel.textContent = opts.cancelLabel || 'Cancel';

    pkEl('pk-modal-ok').replaceWith(ok);
    pkEl('pk-modal-cancel').replaceWith(cancel);

    ok.addEventListener('click', () => { pkModalClose(); if (opts.onOk) opts.onOk(); });
    cancel.addEventListener('click', pkModalClose);
    /* informational modals (a cooldown notice) have nothing to cancel */
    cancel.classList.toggle('hidden', opts.noCancel === true);

    pkEl('pk-modal').classList.remove('hidden');
}

function pkModalClose() { pkEl('pk-modal').classList.add('hidden'); }
function pkModalIsOpen() { return !pkEl('pk-modal').classList.contains('hidden'); }

function pkConfirmUpgrade(p) {
    const from = p.owned ? pkEsc(p.current) : 'Not unlocked';
    const to = pkEsc(p.nextText);
    pkModal({
        title: p.owned ? `Upgrade ${p.name}` : `Unlock ${p.name}`,
        html:
            `<div>Level ${p.rank} to ${p.rank + 1}</div>` +
            `<div class="pk-m-row"><span>${from}</span></div>` +
            '<div class="pk-m-row"><span class="pk-m-arrow">becomes</span></div>' +
            `<div class="pk-m-row"><span>${to}</span></div>` +
            `<div class="pk-m-cost">Cost: ${p.nextCost} perk point${p.nextCost === 1 ? '' : 's'}</div>`,
        okLabel: p.owned ? 'Upgrade' : 'Unlock',
        onOk: () => {
            pkState.pending = p.id;
            pkRenderDetail();
            NUI('perksUpgrade', { id: p.id });
        },
    });
}

function pkConfirmReset() {
    const d = pkState.data;
    if (!d || !d.reset || !d.reset.enabled) return;
    const civ = d.sides.civ || { spent: 0, label: 'Honest Work' };
    const crime = d.sides.crime || { spent: 0, label: 'Outlaw' };
    pkModal({
        title: 'Reset everything?',
        html:
            '<div>Every perk is unlearned and <b>both specialisations are released</b>, so you can pick different paths.</div>' +
            `<div class="pk-m-row"><span>${civ.spent} ${pkEsc(civ.label.toLowerCase())} point${civ.spent === 1 ? '' : 's'} returned</span></div>` +
            `<div class="pk-m-row"><span>${crime.spent} ${pkEsc(crime.label.toLowerCase())} point${crime.spent === 1 ? '' : 's'} returned</span></div>` +
            (d.reset.cost > 0 ? `<div class="pk-m-cost">Cost: $${d.reset.cost}</div>` : ''),
        okLabel: 'Reset',
        danger: true,
        onOk: () => NUI('perksReset', {}),
    });
}

/* ------------------------------------------------------------------ */
/* tooltip                                                             */
/* ------------------------------------------------------------------ */

function pkTipShow(p, anchor) {
    const tip = pkEl('pk-tip');
    const rows = [
        `<div class="pk-tip-name">${pkEsc(p.name)}</div>`,
        `<div class="pk-tip-desc">${pkEsc(p.desc || '')}</div>`,
        '<div class="pk-tip-rule"></div>',
        `<div class="pk-tip-row"><span>Level</span><span>${p.rank} / ${p.maxRank}</span></div>`,
    ];
    if (p.current)  rows.push(`<div class="pk-tip-row"><span>Current</span><span>${pkEsc(p.current)}</span></div>`);
    if (p.nextText) rows.push(`<div class="pk-tip-row"><span>Next</span><span>${pkEsc(p.nextText)}</span></div>`);
    if (p.blocked)  rows.push(`<div class="pk-tip-row bad"><span>Locked</span><span>${pkEsc(p.blocked)}</span></div>`);

    tip.innerHTML = rows.join('');
    tip.classList.remove('hidden');

    /* clamp inside the viewport - a tooltip on the last column must not spill */
    const a = anchor.getBoundingClientRect();
    const t = tip.getBoundingClientRect();
    let left = a.left + a.width / 2 - t.width / 2;
    let top = a.top - t.height - 8;
    if (top < 8) top = a.bottom + 8;
    left = Math.max(8, Math.min(left, window.innerWidth - t.width - 8));
    top = Math.max(8, Math.min(top, window.innerHeight - t.height - 8));
    tip.style.left = left + 'px';
    tip.style.top = top + 'px';
}

function pkTipHide() { pkEl('pk-tip').classList.add('hidden'); }

/* ------------------------------------------------------------------ */
/* open / update / close                                               */
/* ------------------------------------------------------------------ */

function pkRenderAll(prev) {
    pkRenderHeader(prev);
    pkRenderNav();
    pkRenderBody();
    pkRenderSlots(prev);
    pkRenderDetail();
    pkRenderGuide();
}

function openPerks(data) {
    if (!data || !Array.isArray(data.perks)) return;

    /* a genuine open resets the view; a repaint while already open must keep
       the player's tab, search and selection */
    const fresh = pkWrap.classList.contains('hidden');
    if (fresh) {
        /* open on whichever side still has points waiting, so a player is shown
           the decision they actually have to make */
        const civ = data.sides && data.sides.civ;
        const crime = data.sides && data.sides.crime;
        pkState.side = (crime && crime.points > 0 && (!civ || civ.points <= 0)) ? 'crime' : 'civ';
        pkState.cat = 'all';
        pkState.search = '';
        pkState.filter = 'all';
        pkState.sort = 'default';
        pkState.sel = null;
        pkState.tree = false;
        pkState.preview = null;
        pkState.guide = !!data.guide && pkFirstVisit();
        pkEl('pk-search').value = '';
        if (pkPaintFilter) pkPaintFilter();
        if (pkPaintSort) pkPaintSort();
        pkModalClose();
    }

    const prev = pkState.data;
    pkState.data = data;
    pkState.pending = null;
    pkWrap.classList.remove('hidden', 'leaving');
    pkRenderAll(fresh ? null : prev);
}

function updatePerks(data) {
    if (!data || !Array.isArray(data.perks)) return;
    if (pkWrap.classList.contains('hidden')) { pkState.data = data; return; }
    const prev = pkState.data;
    pkState.data = data;
    pkState.pending = null;
    if (pkState.sel && !pkFindPerk(pkState.sel)) pkState.sel = null;
    pkRenderAll(prev);
}

function hidePerks() {
    if (pkWrap.classList.contains('hidden')) return;
    pkModalClose();
    pkTipHide();
    pkWrap.classList.add('leaving');
    setTimeout(() => {
        pkWrap.classList.add('hidden');
        pkWrap.classList.remove('leaving');
    }, 150);
}

function pkClose() {
    hidePerks();
    NUI('perksClose', {});
}

/* ------------------------------------------------------------------ */
/* wiring (once, at load)                                              */
/* ------------------------------------------------------------------ */

pkPaintFilter = pkBuildSelect('pk-filter', PK_FILTERS,
    () => pkState.filter,
    (k) => { pkState.filter = k; pkRenderBody(); });

pkPaintSort = pkBuildSelect('pk-sort', PK_SORTS,
    () => pkState.sort,
    (k) => { pkState.sort = k; pkRenderBody(); });

/* filters as you type - no Enter, and no debounce needed at this list size */
pkEl('pk-search').addEventListener('input', (e) => {
    pkState.search = e.target.value || '';
    pkRenderBody();
});

pkEl('pk-close').addEventListener('click', pkClose);
pkEl('pk-guide-btn').addEventListener('click', pkToggleGuide);
/* nav button = free weekly respec; the picker's = the paid full reset that
   also clears both specialisations */
pkEl('pk-reset').addEventListener('click', pkConfirmWeeklyReset);
pkEl('pk-pick-reset').addEventListener('click', pkConfirmReset);

pkEl('pk-preview-back').addEventListener('click', () => {
    pkState.preview = null;
    pkRenderBody();
});
pkEl('pk-preview-commit').addEventListener('click', () => {
    const c = (pkState.data.cats || []).find((x) => x.key === pkState.preview);
    const s = pkSide();
    if (!c || !s) return;
    /* a switch preview leads to the switch confirm (with its loss warning); a
       first commitment keeps the plain commit dialog */
    if (c.switchable) pkConfirmSwitch(c, s);
    else pkConfirmTree(c, s);
});
pkEl('pk-view-toggle').addEventListener('click', () => {
    pkState.tree = !pkState.tree;
    pkRenderNav();
    pkRenderBody();
});

/* clicking anywhere else in the panel closes an open dropdown */
pkWrap.addEventListener('click', () => {
    document.querySelectorAll('#pk-wrap .pk-select.open').forEach((s) => s.classList.remove('open'));
});

/* the tree measures real element positions, so it is redrawn on resize and on
   any browser-zoom change */
window.addEventListener('resize', () => {
    if (pkState.tree && pkState.data && !pkWrap.classList.contains('hidden')) pkRenderTree();
});

/* ESC: peel one layer at a time - modal, then detail, then the panel */
window.addEventListener('keyup', (e) => {
    if (e.key !== 'Escape') return;
    if (pkWrap.classList.contains('hidden')) return;
    if (pkModalIsOpen()) { pkModalClose(); return; }
    if (pkState.sel) { pkSelect(pkState.sel); return; }
    if (pkState.guide) { pkToggleGuide(); return; }
    pkClose();
}, true);

/* the message router: as its own page, pup-perks listens for its own messages */
window.addEventListener('message', (e) => {
    const msg = e.data || {};
    if (!msg.action) return;
    if (msg.action === 'perks')       { openPerks(msg.data || {}); return; }
    if (msg.action === 'perksUpdate') { updatePerks(msg.data || {}); return; }
    if (msg.action === 'perksHide')   { hidePerks(); return; }
    if (msg.action === 'perksXp')     { pkFlashGain((msg.data && msg.data.gained) || 0); return; }
});

/* the page starts hidden; only a perks message shows it */
pkWrap.classList.add('hidden');
