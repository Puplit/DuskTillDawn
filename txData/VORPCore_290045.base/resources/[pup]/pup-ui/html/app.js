/* pup-ui NUI: banner queue, rank bar, toast stack.
   Icons are unicode symbols (no icon-font dependency in NUI). */

/* ---- debug plumbing (FIRST, so even load-time failures report) ----
   Every uncaught error in this page is forwarded to Lua and printed in
   F8 as [pup-ui JS ERROR]; step traces print as [pup-ui JS]. */
/* NUI callbacks are reachable at the BARE resource name (https://pup-ui/<cb>) -
   that is exactly what GetParentResourceName() (injected into every NUI frame)
   returns. window.location.hostname is the PREFIXED form ("cfx-nui-pup-ui"),
   and https://cfx-nui-pup-ui/<cb> does NOT route to RegisterNUICallback, so every
   JS->Lua call (listSelect, listBack, pupSyncState, inputSubmit, shopBuy, ...)
   404'd silently. That froze every focus-holding menu: the page hid the panel
   but Lua never heard the click, so it kept NUI focus. Match the pattern every
   other resource on this server uses. */
const RESOURCE = (typeof GetParentResourceName === 'function')
    ? GetParentResourceName()
    : window.location.hostname.replace(/^cfx-nui-/, '');
const NUI = (name, data) => fetch(`https://${RESOURCE}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
}).catch(() => {});
const DBG = (msg) => { try { NUI('debugLog', { level: 'log', msg: String(msg) }); } catch (e) { /* ignore */ } };
window.addEventListener('error', (e) => {
    try {
        NUI('debugLog', {
            level: 'error',
            msg: `${e.message || 'unknown error'} @ ${(e.filename || '?').split('/').pop()}:${e.lineno || 0}`,
        });
    } catch (err) { /* ignore */ }
});
window.addEventListener('unhandledrejection', (e) => {
    try { NUI('debugLog', { level: 'error', msg: `unhandled promise rejection: ${e.reason}` }); } catch (err) { /* ignore */ }
});

const banner = document.getElementById('banner');
const bannerTitle = document.getElementById('banner-title');
const bannerSub = document.getElementById('banner-sub');
const toasts = document.getElementById('toasts');

/* ---- banner: one at a time, queued ---- */
let bannerQueue = [];
let bannerBusy = false;

function nextBanner() {
    if (bannerBusy || bannerQueue.length === 0) return;
    bannerBusy = true;
    const item = bannerQueue.shift();

    banner.classList.remove('hidden', 'leaving', 'red');
    if (item.tone === 'red') banner.classList.add('red');
    bannerTitle.textContent = item.title || '';
    bannerSub.textContent = item.subtitle || '';
    bannerSub.style.display = item.subtitle ? '' : 'none';

    setTimeout(() => {
        banner.classList.add('leaving');
        setTimeout(() => {
            banner.classList.add('hidden');
            bannerBusy = false;
            nextBanner();
        }, 500);
    }, item.duration || 5000);
}

/* shared currency formatter (used by the shop + list menu) */
function fmt(n) { return Number(n || 0).toFixed(2); }

/* ---- toasts ---- */
/* ---- monochrome inline-SVG icon set (ox_lib-style named icons). A resource can
   pass a NAME ('coins','skull','law'...) OR keep passing a unicode glyph ('$','★')
   - both resolve to a crisp SVG here; anything unknown falls back to raw text.
   All icons use currentColor, so they inherit the element's colour (white in this
   theme, red on .red toasts). Add more by dropping a 24x24 path into ICON_SVG. ---- */
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
    /* a padlock for locked doors; takes the text colour, so it stays crisp at any size */
    padlock: '<path d="M7.5 10.5V7.6a4.5 4.5 0 0 1 9 0v2.9" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/><rect x="4.5" y="10.2" width="15" height="11" rx="2.2" fill="currentColor"/><circle cx="12" cy="14.9" r="1.55" fill="#140f0a"/><path d="M11.3 15.6h1.4l.35 2.6h-2.1z" fill="#140f0a"/>',
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
    /* the two the seven deadly sins needed that nothing else covered */
    moon:    '<path d="M20.6 15.3A9.1 9.1 0 0 1 8.7 3.4a9.1 9.1 0 1 0 11.9 11.9z"/>',
    goblet:  '<path d="M5.8 3h12.4l-1 6.3a5.2 5.2 0 0 1-4.1 4.3V18h3.6v3H7.3v-3h3.6v-4.4a5.2 5.2 0 0 1-4.1-4.3z"/>',
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
    /* the seven deadly sins (pup_robbery's fence). Traditional symbols: the
       peacock feather, coin, green eye, fire, sleep, the cup and the heart. */
    moon: 'moon', sleep: 'moon', night: 'moon',
    goblet: 'goblet', cup: 'goblet', drink: 'goblet', feast: 'goblet',
    pride: 'feather', greed: 'coins', envy: 'eye', wrath: 'fire',
    sloth: 'moon', gluttony: 'goblet', lust: 'heart',
};
function iconSVG(sym) {
    if (typeof sym !== 'string' || sym === '') return null;
    const key = ICON_ALIAS[sym] || (ICON_SVG[sym] ? sym : null);
    if (!key || !ICON_SVG[key]) return null;
    return `<svg class="pup-svg" viewBox="0 0 24 24" aria-hidden="true">${ICON_SVG[key]}</svg>`;
}

function addToast(data) {
    const el = document.createElement('div');
    el.className = 'toast' + (data.tone === 'red' ? ' red' : '');
    el.innerHTML = `
        <div class="toast-icon"></div>
        <div class="toast-body">
            <div class="toast-title"></div>
            <div class="toast-sub"></div>
        </div>`;
    const _ti = el.querySelector('.toast-icon');
    const _tsvg = iconSVG(data.symbol);
    if (_tsvg) _ti.innerHTML = _tsvg; else _ti.textContent = data.symbol || '✦';
    el.querySelector('.toast-title').textContent = data.title || '';
    const sub = el.querySelector('.toast-sub');
    if (data.subtitle) sub.textContent = data.subtitle; else sub.remove();

    toasts.appendChild(el);
    while (toasts.children.length > 5) toasts.removeChild(toasts.firstChild);

    setTimeout(() => {
        el.classList.add('leaving');
        setTimeout(() => el.remove(), 400);
    }, data.duration || 4000);
}

/* ---- survival HUD (bottom-left): hunger/thirst always, infection when
   bitten, noise while loud ---- */
const hudWrap = document.getElementById('hud-wrap');
const hudState = {
    hunger: 100, thirst: 100, infection: 0, noise: 0, noiseShowAt: 15,
    health: 100, stamina: 100, deadeye: 100,
};

function hudRow(id, frac, lowIsBad) {
    const row = document.getElementById(id);
    if (!row) return null; /* stale-cache armor: never die on missing markup */
    const fill = row.querySelector('.hud-fill');
    const pct = Math.min(100, Math.max(0, frac));
    fill.style.width = `${pct}%`;
    row.classList.toggle('hud-danger', lowIsBad ? pct <= 25 : pct >= 70);
    return row;
}

function renderHud(data) {
    if (data.noiseShowAt !== undefined) hudState.noiseShowAt = data.noiseShowAt;
    ['hunger', 'thirst', 'infection', 'noise', 'health', 'stamina', 'deadeye'].forEach((k) => {
        if (data[k] !== undefined) hudState[k] = data[k];
    });
    if (data.show === false) { hudWrap.classList.add('hidden'); return; }
    if (data.show === true) hudWrap.classList.remove('hidden');

    hudRow('hud-health', hudState.health, true);
    hudRow('hud-stamina', hudState.stamina, true);
    hudRow('hud-deadeye', hudState.deadeye, true);
    hudRow('hud-hunger', hudState.hunger, true);
    hudRow('hud-thirst', hudState.thirst, true);
    const inf = hudRow('hud-infection', hudState.infection, false);
    if (inf) inf.classList.toggle('hidden', hudState.infection <= 0);
    const noi = hudRow('hud-noise', hudState.noise, false);
    if (noi) noi.classList.toggle('hidden', hudState.noise < hudState.noiseShowAt);
}


/* ---- item wheel ---- */
const wheelWrap = document.getElementById('wheel-wrap');
const wheelSvg = document.getElementById('wheel-svg');
const wheelLabel = document.getElementById('wheel-label');
const wheelDesc = document.getElementById('wheel-desc');
/* NUI is defined at the top of this file (debug plumbing) */

function segPath(a0, a1, r0, r1) {
    const p = (a, r) => `${Math.cos(a) * r},${Math.sin(a) * r}`;
    return `M ${p(a0, r0)} A ${r0} ${r0} 0 0 1 ${p(a1, r0)} L ${p(a1, r1)} A ${r1} ${r1} 0 0 0 ${p(a0, r1)} Z`;
}

/* an item wheel carries counts; an emote or action wheel does not */
function wheelHasCount(item) {
    return item && item.count !== undefined && item.count !== null;
}

function openWheel(data) {
    const items = data.items || [];
    /* same minimum, radii and label placement as the radial menu */
    const segs = Math.max(items.length, 4);
    wheelSvg.innerHTML = '';
    const title = data.title || 'Provisions';
    const sub = data.subtitle || 'Select an item to use it.';
    wheelLabel.textContent = title;
    wheelDesc.textContent = sub;

    for (let i = 0; i < segs; i++) {
        const gap = 0.03;
        const a0 = (i / segs) * Math.PI * 2 - Math.PI / 2 + gap;
        const a1 = ((i + 1) / segs) * Math.PI * 2 - Math.PI / 2 - gap;
        const item = items[i];

        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', segPath(a0, a1, 100, 46));
        path.setAttribute('class', 'wheel-seg' + (item ? '' : ' empty'));
        if (item) {
            path.addEventListener('mouseenter', () => {
                wheelLabel.textContent = item.label;
                /* no desc and no count: fall back to the wheel's own subtitle
                   rather than "You carry undefined." */
                wheelDesc.textContent = item.desc
                    || (wheelHasCount(item) ? `You carry ${item.count}.` : sub);
            });
            path.addEventListener('mouseleave', () => {
                wheelLabel.textContent = title;
                wheelDesc.textContent = sub;
            });
            path.addEventListener('click', () => {
                wheelWrap.classList.add('hidden');
                NUI('wheelSelect', { item: item.name });
            });
        }
        wheelSvg.appendChild(path);

        if (item) {
            const mid = (a0 + a1) / 2, rMid = 73;
            const counted = wheelHasCount(item);
            const tx = document.createElementNS('http://www.w3.org/2000/svg', 'text');
            tx.setAttribute('x', Math.cos(mid) * rMid);
            /* with no count under it the label sits on the ring's centre line */
            tx.setAttribute('y', Math.sin(mid) * rMid + (counted ? 0 : 4));
            tx.setAttribute('class', 'wheel-txt');
            tx.textContent = item.label;
            wheelSvg.appendChild(tx);

            if (counted) {
                const ct = document.createElementNS('http://www.w3.org/2000/svg', 'text');
                ct.setAttribute('x', Math.cos(mid) * rMid);
                ct.setAttribute('y', Math.sin(mid) * rMid + 8);
                ct.setAttribute('class', 'wheel-txt wheel-count');
                ct.textContent = `x${item.count}`;
                wheelSvg.appendChild(ct);
            }
        }
    }
    wheelWrap.classList.remove('hidden');
}

window.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && !wheelWrap.classList.contains('hidden')) {
        DBG('ESC -> wheel');
        wheelWrap.classList.add('hidden');
        NUI('wheelClose');
    }
});
window.addEventListener('contextmenu', (e) => {
    if (!wheelWrap.classList.contains('hidden')) {
        DBG('rightclick -> wheel close');
        e.preventDefault();
        wheelWrap.classList.add('hidden');
        NUI('wheelClose');
    }
});

/* ---- radial menu (quick actions, submenu stack) ---- */
const radialWrap = document.getElementById('radial-wrap');
const radialSvg = document.getElementById('radial-svg');
const radialLabel = document.getElementById('radial-label');
const radialDesc = document.getElementById('radial-desc');
let radialStack = []; /* [{title, items}] - last entry is the visible level */

function renderRadial() {
    const level = radialStack[radialStack.length - 1];
    if (!level) return;
    const items = level.items || [];
    const segs = Math.max(items.length, 4);
    radialSvg.innerHTML = '';
    radialLabel.textContent = level.title || 'Actions';
    radialDesc.textContent = radialStack.length > 1 ? 'Right-click to go back.' : 'Select an action.';

    for (let i = 0; i < segs; i++) {
        const gap = 0.03;
        const a0 = (i / segs) * Math.PI * 2 - Math.PI / 2 + gap;
        const a1 = ((i + 1) / segs) * Math.PI * 2 - Math.PI / 2 - gap;
        const item = items[i];

        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', segPath(a0, a1, 100, 46));
        path.setAttribute('class', 'wheel-seg radial-seg' + (item ? '' : ' empty'));
        if (item) {
            path.addEventListener('mouseenter', () => {
                radialLabel.textContent = item.label;
                radialDesc.textContent = item.desc || (item.items ? 'Opens a submenu.' : '');
            });
            path.addEventListener('mouseleave', () => {
                radialLabel.textContent = level.title || 'Actions';
                radialDesc.textContent = radialStack.length > 1 ? 'Right-click to go back.' : 'Select an action.';
            });
            path.addEventListener('click', () => {
                if (item.items && item.items.length) {
                    radialStack.push({ title: item.label, items: item.items });
                    renderRadial();
                } else {
                    radialWrap.classList.add('hidden');
                    radialStack = [];
                    NUI('radialSelect', { id: item.id });
                }
            });
        }
        radialSvg.appendChild(path);

        if (item) {
            const mid = (a0 + a1) / 2, rMid = 73;
            const glyph = document.createElementNS('http://www.w3.org/2000/svg', 'text');
            glyph.setAttribute('x', Math.cos(mid) * rMid);
            glyph.setAttribute('y', Math.sin(mid) * rMid - 4);
            glyph.setAttribute('class', 'radial-glyph');
            glyph.textContent = item.glyph || '✦';
            radialSvg.appendChild(glyph);

            const tx = document.createElementNS('http://www.w3.org/2000/svg', 'text');
            tx.setAttribute('x', Math.cos(mid) * rMid);
            tx.setAttribute('y', Math.sin(mid) * rMid + 10);
            tx.setAttribute('class', 'wheel-txt');
            tx.textContent = item.label + (item.items ? ' ▸' : '');
            radialSvg.appendChild(tx);
        }
    }
    radialWrap.classList.remove('hidden');
}

function openRadial(data) {
    radialStack = [{ title: data.title || 'Actions', items: data.items || [] }];
    renderRadial();
}

function radialBack() {
    if (radialStack.length > 1) {
        radialStack.pop();
        renderRadial();
    } else {
        radialWrap.classList.add('hidden');
        radialStack = [];
        NUI('radialClose');
    }
}

window.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && !radialWrap.classList.contains('hidden')) {
        DBG('ESC -> radial');
        radialWrap.classList.add('hidden');
        radialStack = [];
        NUI('radialClose');
    }
});
window.addEventListener('contextmenu', (e) => {
    if (!radialWrap.classList.contains('hidden')) {
        DBG('rightclick -> radial back (depth ' + radialStack.length + ')');
        e.preventDefault();
        radialBack();
    }
});

/* ---- wanted poster ---- */
const posterWrap = document.getElementById('poster-wrap');
let posterTimer = null;

function showPoster(data) {
    document.getElementById('poster-name').textContent = data.name || 'UNKNOWN';
    document.getElementById('poster-crime').textContent = data.crime || 'Crimes against the living';
    document.getElementById('poster-reward').textContent = data.reward || '';
    posterWrap.classList.remove('hidden', 'leaving');
    clearTimeout(posterTimer);
    posterTimer = setTimeout(() => {
        posterWrap.classList.add('leaving');
        setTimeout(() => posterWrap.classList.add('hidden'), 400);
    }, data.duration || 6000);
}

/* ---- death screen ---- */
const deathWrap = document.getElementById('death-wrap');
let deathTimer = null;

function showDeath(data) {
    const killer = document.getElementById('death-killer');
    if (data.killerName) {
        killer.innerHTML = '';
        const role = document.createElement('span');
        role.className = 'killer-role';
        role.textContent = (data.killerRole ? data.killerRole + ' ' : '');
        killer.appendChild(role);
        killer.appendChild(document.createTextNode(data.killerName));
        killer.style.display = '';
    } else {
        killer.style.display = 'none';
    }
    document.getElementById('death-cause').textContent = data.cause || 'The frontier took another';
    document.getElementById('death-hint').textContent = data.hint || '';

    const count = document.getElementById('death-count');
    clearInterval(deathTimer);
    let seconds = Math.max(0, Math.floor(data.seconds || 0));
    const tick = () => {
        count.textContent = seconds > 0 ? `RESPAWN IN ${seconds}` : '';
        if (seconds <= 0) clearInterval(deathTimer);
        seconds--;
    };
    tick();
    deathTimer = setInterval(tick, 1000);
    deathWrap.classList.remove('hidden');
}

function updateDeath(data) {
    if (data.hint !== undefined) document.getElementById('death-hint').textContent = data.hint;
}

function hideDeath() {
    clearInterval(deathTimer);
    deathWrap.classList.add('hidden');
}

/* ---- honor ---- */
const honorWrap = document.getElementById('honor-wrap');
let honorTimer = null;

function showHonor(data) {
    const value = Math.max(0, Math.min(100, data.value || 50));
    honorWrap.classList.remove('hidden');
    document.getElementById('honor-marker').style.left = `${value}%`;
    const delta = document.getElementById('honor-delta');
    if (data.delta) {
        delta.textContent = data.delta > 0 ? `+${data.delta}` : `${data.delta}`;
        delta.className = data.delta > 0 ? 'up' : 'down';
    } else {
        delta.textContent = '';
    }
    clearTimeout(honorTimer);
    honorTimer = setTimeout(() => honorWrap.classList.add('hidden'), data.duration || 4500);
}

/* ---- player menu ---- */
const pmWrap = document.getElementById('pm-wrap');

function openPlayerMenu(data) {
    document.getElementById('pm-name').textContent = data.name || 'Stranger';
    const sub = document.getElementById('pm-sub');
    sub.innerHTML = '';
    if (data.role) {
        const role = document.createElement('span');
        role.className = 'pm-role-' + data.role;
        role.textContent = data.roleLabel || data.role.toUpperCase();
        sub.appendChild(role);
    }
    if (data.gang) sub.appendChild(document.createTextNode((data.role ? '  —  ' : '') + data.gang));

    const stats = document.getElementById('pm-stats');
    stats.innerHTML = '';
    const addStat = (k, v) => {
        const row = document.createElement('div');
        row.className = 'pm-stat';
        const key = document.createElement('span'); key.className = 'k'; key.textContent = k;
        const val = document.createElement('span'); val.textContent = v;
        row.appendChild(key); row.appendChild(val);
        stats.appendChild(row);
    };
    addStat('Rank', `${data.rank || 1}`);
    if (data.xpFrac !== undefined) {
        const bar = document.createElement('div');
        bar.className = 'pm-bar';
        const fill = document.createElement('div');
        fill.style.width = `${Math.round((data.xpFrac || 0) * 100)}%`;
        bar.appendChild(fill);
        stats.appendChild(bar);
    }
    addStat('Honor', `${data.honor !== undefined ? data.honor : 50} / 100`);
    if (data.infection !== undefined && data.infection > 0) addStat('Infection', `${data.infection} / 100`);
    if (data.heat !== undefined) addStat('Heat', `${data.heat}`);
    if (data.cash !== undefined) addStat('Cash', `$${Number(data.cash).toFixed(2)}`);
    if (data.bloodMoney !== undefined && data.bloodMoney > 0) addStat('Blood money', `$${Number(data.bloodMoney).toFixed(2)}`);

    const perks = document.getElementById('pm-perks');
    perks.innerHTML = '';
    (data.perks || []).forEach((perk) => {
        const row = document.createElement('div');
        row.className = 'pm-perk' + (perk.equipped ? ' equipped' : '') + (perk.locked ? ' locked' : '');
        const left = document.createElement('div');
        const name = document.createElement('div'); name.className = 'pm-perk-name'; name.textContent = perk.name;
        const desc = document.createElement('div'); desc.className = 'pm-perk-desc'; desc.textContent = stripBr(perk.desc || '');
        left.appendChild(name); left.appendChild(desc);
        const tag = document.createElement('div'); tag.className = 'pm-perk-tag';
        tag.textContent = perk.locked ? `REQUIRES LEVEL ${perk.rank}` : (perk.equipped ? 'EQUIPPED' : 'EQUIP');
        row.appendChild(left); row.appendChild(tag);
        if (!perk.locked) {
            row.addEventListener('click', () => {
                pmWrap.classList.add('hidden');
                NUI('pmTogglePerk', { id: perk.id });
            });
        }
        perks.appendChild(row);
    });

    pmWrap.classList.remove('hidden');
}

/* ---- shop (categorized; locked items show REQUIRES LEVEL X) ---- */
const shopWrap = document.getElementById('shop-wrap');
let shopState = null; /* { label, data, cats, cat } */

function shopItemCategory(item) {
    return (item.category || 'Miscellaneous');
}

function shopCategories(data) {
    const items = data.items || [];
    if (!data.categories && !items.some((i) => i.category)) return null; /* legacy flat shop */
    const order = (data.categories || []).slice();
    const seen = new Set(order.map((c) => c.toLowerCase()));
    items.forEach((i) => {
        const c = shopItemCategory(i);
        if (!seen.has(c.toLowerCase())) { order.push(c); seen.add(c.toLowerCase()); }
    });
    return order.filter((c) => items.some((i) => shopItemCategory(i).toLowerCase() === c.toLowerCase()));
}

function renderShopTabs() {
    const tabs = document.getElementById('shop-cats');
    if (!shopState.cats) { tabs.classList.add('hidden'); return; }
    tabs.innerHTML = '';
    shopState.cats.forEach((cat) => {
        const el = document.createElement('div');
        el.className = 'shop-cat' + (cat === shopState.cat ? ' active' : '');
        el.textContent = cat;
        el.addEventListener('click', () => {
            shopState.cat = cat;
            renderShopTabs();
            renderShopItems();
        });
        tabs.appendChild(el);
    });
    tabs.classList.remove('hidden');
}

function renderShopItems() {
    const data = shopState.data;
    const list = document.getElementById('shop-items');
    list.innerHTML = '';
    let items = data.items || [];
    if (shopState.cat) {
        items = items.filter((i) => shopItemCategory(i).toLowerCase() === shopState.cat.toLowerCase());
    }
    items.forEach((item) => {
        const locked = data.rank !== undefined && (item.rankreq || 0) > data.rank;
        const broke = (data.cash !== undefined) && (item.price || 0) > data.cash;
        const el = document.createElement('div');
        el.className = 'shop-item' + (locked ? ' locked' : (broke ? ' broke' : ''));

        /* optional thumbnail (item.img = any nui:// url). Hidden on load
           failure so a missing file leaves a clean row, not a broken icon. */
        if (item.img) {
            const thumb = document.createElement('img');
            thumb.className = 'shop-item-thumb';
            thumb.src = item.img;
            thumb.alt = '';
            thumb.onerror = () => thumb.remove();
            el.appendChild(thumb);
        }

        const left = document.createElement('div');
        const name = document.createElement('div');
        name.className = 'shop-item-name';
        name.textContent = item.label;
        left.appendChild(name);
        if (item.description) {
            const desc = document.createElement('div');
            desc.className = 'shop-item-desc';
            desc.textContent = stripBr(item.description);
            left.appendChild(desc);
        }
        /* optional stat chips (item.stats = ['30 MPH', '1000 coal']) - the
           headline numbers, pulled out of the description so they read at a
           glance instead of being buried in a sentence */
        if (Array.isArray(item.stats) && item.stats.length) {
            const row = document.createElement('div');
            row.className = 'shop-item-stats';
            item.stats.forEach((s) => {
                const chip = document.createElement('span');
                chip.className = 'shop-item-stat';
                chip.textContent = s;
                row.appendChild(chip);
            });
            left.appendChild(row);
        }
        /* the level requirement is ALWAYS visible on gated items - red when
           you don't meet it, gold when you do (or when rank is unknown) */
        if ((item.rankreq || 0) > 0) {
            const need = document.createElement('div');
            need.className = 'shop-item-need' + (locked ? '' : ' met');
            need.textContent = `Requires Level ${item.rankreq}`;
            left.appendChild(need);
        }

        const right = document.createElement('div');
        right.className = 'shop-item-right';
        const price = document.createElement('div');
        price.className = 'shop-item-price';
        price.textContent = '$' + fmt(item.price);
        right.appendChild(price);
        if (locked) {
            const tag = document.createElement('div');
            tag.className = 'shop-item-tag';
            tag.textContent = 'LOCKED';
            right.appendChild(tag);
        }

        el.appendChild(left); el.appendChild(right);
        if (!locked) {
            el.addEventListener('click', () => NUI('shopBuy', { name: item.name }));
        } else {
            /* clicking a locked item must SAY why instead of doing nothing */
            el.addEventListener('click', () => addToast({
                title: `Requires Level ${item.rankreq}`,
                subtitle: data.rank !== undefined ? `You don't have the required level — you are level ${data.rank}.` : 'You don\'t have the required level.',
                symbol: '✖',
                tone: 'red',
                duration: 3500,
            }));
        }
        list.appendChild(el);
    });
}

function openShop(data) {
    document.getElementById('shop-title').textContent = data.label || 'Store';
    document.getElementById('shop-purse').textContent = `$${fmt(data.cash)}` + (data.rank ? `  ·  Level ${data.rank}` : '');

    const cats = shopCategories(data);
    /* refreshes of the same shop (e.g. after a buy) keep the selected tab */
    const label = data.label || '';
    let cat = cats ? cats[0] : null;
    if (shopState && shopState.label === label && shopState.cat && cats && cats.includes(shopState.cat)) {
        cat = shopState.cat;
    }
    shopState = { label, data, cats, cat };
    renderShopTabs();
    renderShopItems();
    shopWrap.classList.remove('hidden');
}

/* ---- wardrobe (tabs + slider rows) ---- */
const wardWrap = document.getElementById('ward-wrap');
let wardState = null; /* { data, cat } - cat survives repaints */

function wardRenderTabs() {
    const tabs = document.getElementById('ward-cats');
    tabs.innerHTML = '';
    (wardState.data.cats || []).forEach((c) => {
        const el = document.createElement('div');
        el.className = 'shop-cat' + (c.id === wardState.cat ? ' active' : '');
        el.textContent = c.label || c.id;
        el.addEventListener('click', () => {
            wardState.cat = c.id;
            wardRenderTabs();
            wardRenderItems();
        });
        tabs.appendChild(el);
    });
}

function wardCtl(item, isVariant) {
    const ctl = document.createElement('div');
    ctl.className = 'ward-ctl';
    const mk = (dir) => {
        const a = document.createElement('span');
        a.className = 'ward-arr';
        a.innerHTML = dir < 0 ? '&#10094;' : '&#10095;';
        a.addEventListener('click', () => {
            if (isVariant) {
                const n = item.variantCount || 1;
                item.variant = ((((item.variant || 1) - 1 + dir) % n) + n) % n + 1;
            } else {
                const n = (item.count || 0) + 1; /* slot 0 = NONE */
                item.value = ((((item.value || 0) + dir) % n) + n) % n;
                /* provisional until Lua answers with the real variant count */
                item.variant = 1;
                item.variantCount = 1;
            }
            NUI('wardrobeChange', { id: item.id, value: item.value, variant: item.variant || 1 });
            wardRenderItems();
        });
        return a;
    };
    const val = document.createElement('span');
    val.className = 'ward-val' + (!isVariant && !item.value ? ' none' : '');
    val.textContent = isVariant
        ? `${item.variant || 1}/${item.variantCount || 1}`
        : (item.value ? `${item.value}/${item.count}` : 'NONE');
    ctl.appendChild(mk(-1));
    ctl.appendChild(val);
    ctl.appendChild(mk(1));
    return ctl;
}

function wardRenderItems() {
    const list = document.getElementById('ward-items');
    list.innerHTML = '';
    (wardState.data.items || []).forEach((item) => {
        if (wardState.cat && item.cat !== wardState.cat) return;
        const row = document.createElement('div');
        row.className = 'ward-row' + (item.value > 0 ? ' on' : '');
        const label = document.createElement('div');
        label.className = 'ward-row-label';
        label.textContent = item.label || item.id;
        row.appendChild(label);
        row.appendChild(wardCtl(item, false));
        list.appendChild(row);
        /* a picked item with alternate looks grows a Style sub-row */
        if (item.value > 0 && (item.variantCount || 1) > 1) {
            const vrow = document.createElement('div');
            vrow.className = 'ward-row variant';
            const vlabel = document.createElement('div');
            vlabel.className = 'ward-row-label';
            vlabel.textContent = 'Style';
            vrow.appendChild(vlabel);
            vrow.appendChild(wardCtl(item, true));
            list.appendChild(vrow);
        }
    });
}

function openWardrobe(data) {
    if (!wardWrap) { DBG('openWardrobe: markup missing (stale index.html cache)'); return; }
    document.getElementById('ward-title').textContent = data.title || 'WARDROBE';
    const sub = document.getElementById('ward-sub');
    sub.textContent = data.subtitle || '';
    sub.style.display = data.subtitle ? '' : 'none';
    document.getElementById('ward-foot').textContent =
        data.foot || 'Arrows to change — ESC to cancel';
    const cats = data.cats || [];
    let cat = cats.length ? cats[0].id : null;
    if (wardState && wardState.cat && cats.some((c) => c.id === wardState.cat)) {
        cat = wardState.cat; /* reopening keeps the tab you were on */
    }
    wardState = { data, cat };
    wardRenderTabs();
    wardRenderItems();
    wardWrap.classList.remove('hidden');
}

function wardUpdate(u) {
    if (!wardState || !u || !u.id) return;
    const item = (wardState.data.items || []).find((i) => i.id === u.id);
    if (!item) return;
    if (u.value !== undefined) item.value = u.value;
    if (u.variant !== undefined) item.variant = u.variant;
    if (u.variantCount !== undefined) item.variantCount = u.variantCount;
    wardRenderItems();
}

/* stale-cache armor: if the client cached an old index.html without the
   wardrobe markup, a throw HERE at load time would kill every handler
   registered below it - the "panel shows NO ANSWER" freeze. Never assume
   the markup exists. */
const wardSaveBtn = document.getElementById('ward-save');
if (wardSaveBtn) wardSaveBtn.addEventListener('click', () => NUI('wardrobeSave'));
document.querySelectorAll('.ward-rot').forEach((el) => {
    el.addEventListener('click', () => NUI('wardrobeRotate', { dir: Number(el.dataset.dir) || 1 }));
});
if (!wardWrap) DBG('wardrobe markup missing - stale index.html cache? (restart pup-ui / clear RedM cache)');

/* ---- prompt (RDR2 bottom key pill) ---- */
const promptWrap = document.getElementById('prompt-wrap');

function showPrompt(data) {
    const key = document.getElementById('prompt-key');
    key.textContent = data.key || '';
    // set here too: a cached stylesheet left this in the display face, where a
    // capital G is near indistinguishable from a B
    key.style.fontFamily = "Georgia, 'Times New Roman', serif";
    key.style.display = data.key ? '' : 'none';
    document.getElementById('prompt-label').textContent = data.label || '';
    promptWrap.classList.remove('hidden');
}

/* ---- floating world key cap ---- */
const wkWrap = document.getElementById('wk-wrap');
const wkCap = document.getElementById('wk-cap');
const wkRule = document.getElementById('wk-rule');
const wkText = document.getElementById('wk-text');

function showWorldKey(d) {
    const cap = d.key || '';
    const txt = d.text || '';
    if (wkCap.textContent !== cap) {
        wkCap.textContent = cap;
        wkCap.style.fontFamily = "Georgia, 'Times New Roman', serif";
    }
    if (wkText.textContent !== txt) wkText.textContent = txt;
    // set every time: an empty cap starting empty would never get hidden
    wkCap.classList.toggle('wk-empty', !cap);
    wkRule.classList.toggle('wk-empty', !cap); // only a separator when there is a cap
    wkText.classList.toggle('wk-empty', !txt);
    wkWrap.classList.toggle('wk-denied', d.tone === 'denied');
    // x/y arrive as 0-1 screen coords
    wkWrap.style.left = (d.x * 100) + '%';
    wkWrap.style.top = (d.y * 100) + '%';
    wkWrap.classList.remove('hidden');
}

function hideWorldKey() { wkWrap.classList.add('hidden'); }

/* ---- door lock audio ----
   Lock and unlock play pup-minigames' safe crack samples (silent when it is not installed).
   Swap a path here to change what a door sounds like. */
const DOOR_SOUNDS = {
    lock:   'nui://pup-minigames/html/assets/audio/safe_lock_6.mp3',
    unlock: 'nui://pup-minigames/html/assets/audio/safe_lock_5.mp3',
    denied: 'audio/door_denied.ogg',
};
const DOOR_VOLUME = 0.45;

const doorAudio = {};

function playDoorSound(kind) {
    const path = DOOR_SOUNDS[kind] || DOOR_SOUNDS.unlock;
    let a = doorAudio[path];
    if (!a) {
        a = new Audio(path);
        a.preload = 'auto';
        doorAudio[path] = a;
    }
    a.volume = DOOR_VOLUME;
    // rewind so a second press retriggers instead of being ignored
    try { a.currentTime = 0; } catch (e) { /* not buffered yet */ }
    const p = a.play();
    if (p && p.catch) p.catch(() => {});
}

/* ---- progress bar (replaces vorp_progressbar) ---- */
const progWrap = document.getElementById('prog-wrap');
const progLabel = document.getElementById('prog-label');
const progPct = document.getElementById('prog-pct');
const progFill = document.getElementById('prog-fill');
const progRing = document.getElementById('prog-ring-fg');
const PROG_RING_LEN = 251.33; // 2 * PI * 40
let progRAF = null;
let progToken = 0;

/* one place draws the fill, so the line and the ring always agree */
function setProgFrac(frac) {
    progFill.style.width = (frac * 100) + '%';
    progPct.textContent = Math.round(frac * 100) + '%';
    if (progRing) progRing.style.strokeDashoffset = (PROG_RING_LEN * (1 - frac)).toFixed(2);
}

/* 'line' or 'ring', from Config.Progress.style or the player's /hud pick */
function setProgressStyle(d) {
    const ring = d && d.style === 'ring';
    progWrap.classList.toggle('style-ring', ring);
    progWrap.classList.toggle('style-line', !ring);
}

function startProgress(data) {
    const dur = Math.max(1, Number(data.duration) || 5000);
    const token = ++progToken; // any new/cancel invalidates a running animation
    if (progRAF) { cancelAnimationFrame(progRAF); progRAF = null; }
    progLabel.textContent = data.label || '';
    setProgFrac(0);
    progWrap.classList.remove('hidden');
    let startTs = null;
    function step(ts) {
        if (token !== progToken) return; // replaced or cancelled
        if (startTs === null) startTs = ts;
        const frac = Math.min(1, (ts - startTs) / dur);
        setProgFrac(frac);
        if (frac >= 1) {
            progRAF = null;
            progWrap.classList.add('hidden');
            NUI('progressDone');
            return;
        }
        progRAF = requestAnimationFrame(step);
    }
    progRAF = requestAnimationFrame(step);
}

function hideProgress() {
    progToken++; // invalidate the running animation so progressDone won't fire
    if (progRAF) { cancelAnimationFrame(progRAF); progRAF = null; }
    progWrap.classList.remove('prog-edit');
    progWrap.classList.add('hidden');
}

/* /hud editor: the saved offset, and a dummy bar to grab while editing */
function progressPos(d) {
    progWrap.style.setProperty('--prog-dx', (Number(d.dx) || 0) + 'px');
    progWrap.style.setProperty('--prog-dy', (Number(d.dy) || 0) + 'px');
    if (d.editing) {
        if (progRAF) { cancelAnimationFrame(progRAF); progRAF = null; }
        progLabel.textContent = 'Progress Bar';
        setProgFrac(0.6);
        progWrap.classList.add('prog-edit');
        progWrap.classList.remove('hidden');
    } else if (progWrap.classList.contains('prog-edit')) {
        progWrap.classList.remove('prog-edit');
        progWrap.classList.add('hidden');
    }
}

/* ---- list menu (RDR2 ink list) ---- */
const listWrap = document.getElementById('list-wrap');
const listOptionsEl = document.getElementById('list-options');
const listToolsEl = document.getElementById('list-tools');
const listSearchEl = document.getElementById('list-search');
const listFilterEl = document.getElementById('list-filter');

/* a search over a couple of thousand rows must not build a couple of thousand nodes */
const LIST_RENDER_CAP = 300;

/* keyboard cursor: Lua polls the game controls and pushes the row here, so the
   highlight works with or without NUI focus */
let listOptEls = [];
let listRows = []; // { option, index } - index is the ORIGINAL 1-based position

function listSetSel(index) {
    // match on the original index, so a filtered list still highlights the right row
    let pos = -1;
    for (let i = 0; i < listOptEls.length; i++) {
        if (listOptEls[i]._idx === index) { pos = i; break; }
    }
    listOptEls.forEach((el, i) => el.classList.toggle('sel', i === pos));
    const el = listOptEls[pos];
    if (el && el.scrollIntoView) el.scrollIntoView({ block: 'nearest' });
}

function buildListRow(option, index) {
    const el = document.createElement('div');
    el.className = 'list-opt';
    el._idx = index; // the ORIGINAL index: filtering must never shift what Lua is told
    // optional right-aligned value/price (vorp_menu label-slider value / descPrice parity):
    //   option.price -> gold "$X.XX"   |   option.value -> plain right-side text
    const rightText = option.price !== undefined ? ('$' + fmt(option.price))
        : (option.value !== undefined && option.value !== null ? String(option.value) : null);
    /* optional leading icon (same inline-SVG set the target stack uses),
       so a list menu can look exactly like the hold-B option cards */
    if (option.icon) {
        el.classList.add('has-icon');
        const ico = document.createElement('span');
        ico.className = 'list-opt-icon';
        ico.innerHTML = iconSVG(option.icon);
        el.appendChild(ico);
    }
    let host = el;
    if (rightText !== null || option.icon) {
        if (rightText !== null) el.classList.add('has-value');
        host = document.createElement('div');
        host.className = 'list-opt-main';
        el.appendChild(host);
    }
    const label = document.createElement('div');
    label.className = 'list-opt-label';
    label.textContent = option.label || '';
    host.appendChild(label);
    if (option.desc) {
        const desc = document.createElement('div');
        desc.className = 'list-opt-desc';
        desc.textContent = stripBr(option.desc);
        host.appendChild(desc);
    }
    if (rightText !== null) {
        const val = document.createElement('div');
        val.className = 'list-opt-value' + (option.price !== undefined ? ' price' : '');
        val.textContent = rightText;
        el.appendChild(val);
    }
    if (option.disabled) {
        // info/header row (vorp_menu isDisabled): shown but not selectable
        el.classList.add('disabled');
    } else {
        el.addEventListener('click', () => {
            listWrap.classList.add('hidden');
            NUI('listSelect', { index });
        });
    }
    return el;
}

function listNote(label, desc) {
    const el = document.createElement('div');
    el.className = 'list-opt disabled';
    const l = document.createElement('div');
    l.className = 'list-opt-label';
    l.textContent = label;
    el.appendChild(l);
    if (desc) {
        const d = document.createElement('div');
        d.className = 'list-opt-desc';
        d.textContent = desc;
        el.appendChild(d);
    }
    return el;
}

/* rebuild the visible rows from the search box and the category dropdown.
   option.pinned ignores both, so an action row stays reachable at any search */
function listApplyFilter() {
    const q = (listSearchEl.value || '').trim().toLowerCase();
    const f = listFilterEl.value || '';
    listOptionsEl.innerHTML = '';
    listOptEls = [];
    let matched = 0;
    let shown = 0;
    for (let i = 0; i < listRows.length; i++) {
        const option = listRows[i].option;
        if (!option.pinned) {
            if (f && String(option.group || '') !== f) continue;
            if (q) {
                const hay = ((option.label || '') + ' ' + (option.desc || '')).toLowerCase();
                if (hay.indexOf(q) === -1) continue;
            }
        }
        matched++;
        if (shown >= LIST_RENDER_CAP) continue;
        const el = buildListRow(option, listRows[i].index);
        listOptEls.push(el);
        listOptionsEl.appendChild(el);
        shown++;
    }
    if (matched === 0) {
        listOptionsEl.appendChild(listNote('No matches', 'Nothing here matches that search'));
    } else if (matched > shown) {
        listOptionsEl.appendChild(listNote((matched - shown) + ' more not shown', 'Keep typing to narrow the list'));
    }
}

function openListMenu(data) {
    document.getElementById('list-title').textContent = data.title || '';
    const sub = document.getElementById('list-sub');
    sub.textContent = data.subtitle || '';
    // optional leading icon on the subtitle, same registry the options use
    const subSvg = data.subtitle ? iconSVG(data.subtitleIcon) : null;
    if (subSvg) sub.insertAdjacentHTML('afterbegin', subSvg);
    sub.style.display = data.subtitle ? '' : 'none';

    listRows = (data.options || []).map((option, i) => ({ option, index: i + 1 }));

    // opt-in tools: data.search (true, or a placeholder string) and data.filters
    const filters = Array.isArray(data.filters) ? data.filters : [];
    const wantTools = !!(data.search || filters.length);
    listToolsEl.classList.toggle('hidden', !wantTools);
    listSearchEl.style.display = data.search ? '' : 'none';
    listSearchEl.value = '';
    listSearchEl.placeholder = (typeof data.search === 'string' && data.search) || 'Search';
    listFilterEl.style.display = filters.length ? '' : 'none';
    listFilterEl.innerHTML = '';
    filters.forEach((f) => {
        const opt = document.createElement('option');
        if (typeof f === 'string') { opt.value = f; opt.textContent = f || 'All'; }
        else { opt.value = f.value || ''; opt.textContent = f.label || f.value || 'All'; }
        listFilterEl.appendChild(opt);
    });

    listApplyFilter();
    listWrap.classList.remove('hidden');
    if (data.index) listSetSel(data.index);
    if (wantTools && data.search) { try { listSearchEl.focus(); } catch (e) { /* no focus, no search */ } }
}

listSearchEl.addEventListener('input', listApplyFilter);
listFilterEl.addEventListener('change', listApplyFilter);

function closeListMenu(sendBack) {
    listWrap.classList.add('hidden');
    if (sendBack) NUI('listBack');
}

window.addEventListener('mouseup', (e) => {
    if (e.button === 2 && !listWrap.classList.contains('hidden')) {
        DBG('rightclick -> list back');
        e.preventDefault();
        closeListMenu(true);
    }
});

/* ---- ink input form (the pup-ui inputDialog) ---- */
const inputWrap = document.getElementById('input-wrap');
let inputFields = [];
let inputOpenedAt = 0; // guards against the opening keypress auto-repeating into the form

function openInkInput(data) {
    inputOpenedAt = Date.now();
    document.getElementById('input-title').textContent = data.title || '';
    const sub = document.getElementById('input-sub');
    sub.textContent = data.subtitle || '';
    sub.style.display = data.subtitle ? '' : 'none';
    document.getElementById('input-submit').textContent = (data.submit || 'Confirm').toUpperCase();

    inputFields = data.fields || [];
    const wrap = document.getElementById('input-fields');
    wrap.innerHTML = '';
    inputFields.forEach((f, i) => {
        const row = document.createElement('label');
        row.className = 'input-row';
        const lab = document.createElement('div');
        lab.className = 'input-label';
        lab.textContent = f.label || '';
        row.appendChild(lab);
        let el;
        if (f.type === 'select') {
            el = document.createElement('select');
            (f.options || []).forEach((o) => {
                const opt = document.createElement('option');
                opt.value = o.value !== undefined ? o.value : o.label;
                opt.textContent = o.label;
                el.appendChild(opt);
            });
            if (f.default !== undefined) el.value = f.default;
        } else if (f.type === 'textarea') {
            // multi-line input (vorp_inputs textarea parity). Enter inserts a
            // newline here instead of submitting (see the keydown handler below).
            el = document.createElement('textarea');
            el.spellcheck = false;
            el.rows = f.rows || 4;
            if (f.placeholder) el.placeholder = f.placeholder;
            if (f.default !== undefined) el.value = f.default;
            if (f.maxlength !== undefined) el.maxLength = f.maxlength;
        } else {
            el = document.createElement('input');
            el.type = f.type === 'number' ? 'number' : 'text';
            el.spellcheck = false;
            if (f.placeholder) el.placeholder = f.placeholder;
            if (f.default !== undefined) el.value = f.default;
            if (f.min !== undefined) el.min = f.min;
            if (f.max !== undefined) el.max = f.max;
            if (f.maxlength !== undefined) el.maxLength = f.maxlength;
        }
        el.className = 'input-field';
        el.dataset.i = i;
        row.appendChild(el);
        wrap.appendChild(row);
    });
    inputWrap.classList.remove('hidden');
    const first = wrap.querySelector('.input-field');
    if (first) setTimeout(() => first.focus(), 50);
}

function collectInkInput() {
    const values = [];
    let ok = true;
    document.querySelectorAll('#input-fields .input-field').forEach((el) => {
        const f = inputFields[Number(el.dataset.i)] || {};
        let v = el.value;
        if (f.type === 'number') {
            v = v === '' ? null : Number(v);
            if (v !== null && f.min !== undefined && v < f.min) v = Number(f.min);
            if (v !== null && f.max !== undefined && v > f.max) v = Number(f.max);
        }
        if (f.required && (v === null || v === '')) {
            ok = false;
            el.classList.add('bad');
        } else {
            el.classList.remove('bad');
        }
        values.push(v);
    });
    return ok ? values : null;
}

function submitInkInput() {
    const values = collectInkInput();
    if (!values) return;
    inputWrap.classList.add('hidden');
    NUI('inputSubmit', { values });
}

document.getElementById('input-submit').addEventListener('click', submitInkInput);
document.getElementById('input-cancel').addEventListener('click', () => {
    inputWrap.classList.add('hidden');
    NUI('inputCancel');
});
window.addEventListener('keydown', (e) => {
    if (inputWrap.classList.contains('hidden')) return;
    if (e.key === 'Enter' && e.target && e.target.tagName !== 'SELECT' && e.target.tagName !== 'TEXTAREA') {
        e.preventDefault();
        // the ENTER that opened this form (selecting a menu row) can auto-repeat
        // into the freshly-focused page and submit an EMPTY form instantly -
        // which legacy callers read as "cancelled". Ignore Enter briefly.
        if (Date.now() - inputOpenedAt < 350) return;
        submitInkInput();
    }
});

/* ---- ink menu (keyboard list with slider rows; no NUI focus) ---- */
const inkWrap = document.getElementById('ink-wrap');
const inkOptions = document.getElementById('ink-options');
const inkImg = document.getElementById('ink-img');
let inkData = null;

/* Reference art for the focused row. A row without `image` hides it, so menus
   that never set one show no art. */
function updateInkImage() {
    if (!inkImg) return;
    const opt = inkData && inkData.options ? inkData.options[inkData.index - 1] : null;
    const src = opt && opt.image;
    if (!src) {
        inkImg.classList.add('hidden');
        inkImg.removeAttribute('src');
        return;
    }
    if (inkImg.getAttribute('src') !== src) inkImg.setAttribute('src', src);
    inkImg.classList.remove('hidden');
}

/* An item with no art would otherwise leave a broken-image box beside the menu. */
if (inkImg) {
    inkImg.addEventListener('error', () => {
        inkImg.classList.add('hidden');
        inkImg.removeAttribute('src');
    });
}

function inkValueText(opt) {
    if (!opt.values || !opt.values.length) return '';
    const idx = Math.min(Math.max(opt.valueIndex || 1, 1), opt.values.length);
    if (opt.noneFirst && idx === 1) return 'None';
    return `${opt.values[idx - 1]}`;
}

function inkCountText(opt) {
    if (!opt.values || !opt.values.length) return '';
    const idx = Math.min(Math.max(opt.valueIndex || 1, 1), opt.values.length);
    // a leading "None" slot is not one of the choices: 7 parts read 1/7..7/7, not 2/8..8/8
    if (opt.noneFirst) return idx === 1 ? '' : `${idx - 1}/${opt.values.length - 1}`;
    return `${idx}/${opt.values.length}`;
}

/* ---------- price picker ----------
   Values are NOTCHES (0..steps); the money shown is worked out from min/max so
   the page never has to be told a price it could then send back. */
let priceData = null;

function priceMoney(v, prefix) {
    return (prefix || '$') + Math.round(v);
}

function priceAt(d, notch) {
    if (d.steps <= 0) return d.min;
    return d.min + (d.max - d.min) * (notch / d.steps);
}

function pricePickerPaint() {
    const d = priceData;
    if (!d) return;
    const pct = d.steps > 0 ? (d.notch / d.steps) * 100 : 0;
    document.getElementById('price-cur').textContent = priceMoney(priceAt(d, d.notch), d.prefix);
    document.getElementById('price-fill').style.width = pct + '%';
    document.getElementById('price-handle').style.left = pct + '%';
}

function pricePickerOpen(d) {
    priceData = {
        min: Number(d.min) || 0, max: Number(d.max) || 0,
        steps: Math.max(1, Number(d.steps) || 12),
        notch: Math.max(0, Number(d.notch) || 0),
        prefix: d.prefix || '$',
    };
    document.getElementById('price-caption').textContent = d.caption || '';
    document.getElementById('price-title').textContent = d.title || '';
    document.getElementById('price-min').textContent = priceMoney(priceData.min, priceData.prefix);
    document.getElementById('price-max').textContent = priceMoney(priceData.max, priceData.prefix);
    document.getElementById('price-foot').innerHTML = d.foot ||
        '&#8592;&#8594; adjust &nbsp; <b>ENTER</b> confirm &nbsp; <b>BACKSPACE</b> cancel';
    pricePickerPaint();
    document.getElementById('price-wrap').classList.remove('hidden');
}

function pricePickerState(s) {
    if (!priceData) return;
    if (s.notch !== undefined) priceData.notch = Number(s.notch) || 0;
    pricePickerPaint();
}

// how far along its range a slider row sits, 0-100
function inkSliderPct(opt) {
    if (!opt.values || opt.values.length < 2) return 0;
    const idx = Math.min(Math.max(opt.valueIndex || 1, 1), opt.values.length);
    return ((idx - 1) / (opt.values.length - 1)) * 100;
}

// the markup's own nav line, kept so a menu without hints is unchanged
let inkFootDefault = null;

// optional key chips under the list: [{ keys: ['A','S'], label: 'Turn' }]
function renderInkFoot() {
    const foot = document.getElementById('ink-foot');
    if (!foot) return;
    if (inkFootDefault === null) inkFootDefault = foot.innerHTML;

    const hints = (inkData && inkData.hints) || null;
    if (!hints || !hints.length) {
        foot.innerHTML = inkFootDefault;
        return;
    }

    foot.innerHTML = '';
    const row = document.createElement('div');
    row.className = 'ink-hints';
    hints.forEach((h) => {
        const hint = document.createElement('span');
        hint.className = 'ink-hint';
        (h.keys || []).forEach((k, i) => {
            if (i > 0) {
                const sep = document.createElement('span');
                sep.className = 'ink-hint-sep';
                sep.textContent = '/';
                hint.appendChild(sep);
            }
            const key = document.createElement('span');
            key.className = 'ink-key';
            key.textContent = k;
            hint.appendChild(key);
        });
        const label = document.createElement('span');
        label.className = 'ink-hint-label';
        label.textContent = h.label || '';
        hint.appendChild(label);
        row.appendChild(hint);
    });
    foot.appendChild(row);

    const nav = document.createElement('div');
    nav.className = 'ink-foot-nav';
    nav.innerHTML = inkFootDefault;
    foot.appendChild(nav);
}

function renderInkMenu() {
    if (!inkData) return;
    document.getElementById('ink-title').textContent = inkData.title || '';
    const sub = document.getElementById('ink-sub');
    sub.textContent = inkData.subtitle || '';
    sub.style.display = inkData.subtitle ? '' : 'none';

    inkOptions.innerHTML = '';
    (inkData.options || []).forEach((opt, i) => {
        const el = document.createElement('div');
        el.className = 'ink-opt' + (i + 1 === inkData.index ? ' focused' : '');
        el.dataset.i = i;

        const left = document.createElement('div');
        left.className = 'ink-opt-left';
        const label = document.createElement('div');
        label.className = 'ink-opt-label';
        label.textContent = opt.label || '';
        left.appendChild(label);
        if (opt.description) {
            const desc = document.createElement('div');
            desc.className = 'ink-opt-desc';
            desc.textContent = stripBr(opt.description);
            left.appendChild(desc);
        }
        el.appendChild(left);

        if (opt.values && opt.values.length) {
            const right = document.createElement('div');
            right.className = 'ink-opt-value';
            right.innerHTML = `<span class="ink-arr">&#10094;</span><span class="ink-val">${inkValueText(opt)}</span><span class="ink-arr">&#10095;</span><span class="ink-count">${inkCountText(opt)}</span>`;
            el.appendChild(right);
        }
        // opt-in slider track: a filled bar showing where the value sits in its
        // range. Only rows that ask for it get one, so other menus are unchanged.
        if (opt.slider && opt.values && opt.values.length) {
            const track = document.createElement('div');
            track.className = 'ink-slider';
            track.innerHTML = `<div class="ink-slider-fill" style="width:${inkSliderPct(opt)}%"></div>`;
            el.appendChild(track);
            el.classList.add('has-slider');
        }
        inkOptions.appendChild(el);
    });
    renderInkFoot();
    scrollInkFocus();
    updateInkImage();
}

function scrollInkFocus() {
    const focused = inkOptions.querySelector('.ink-opt.focused');
    if (focused) focused.scrollIntoView({ block: 'nearest' });
}

function inkMenuState(state) {
    if (!inkData) return;
    if (state.index !== undefined) inkData.index = state.index;
    const opt = inkData.options[inkData.index - 1];
    if (opt && state.valueIndex !== undefined) opt.valueIndex = state.valueIndex;

    inkOptions.querySelectorAll('.ink-opt').forEach((el) => {
        const isFocused = Number(el.dataset.i) + 1 === inkData.index;
        el.classList.toggle('focused', isFocused);
        if (isFocused && opt && opt.values && state.valueIndex !== undefined) {
            const val = el.querySelector('.ink-val');
            const count = el.querySelector('.ink-count');
            if (val) val.textContent = inkValueText(opt);
            if (count) count.textContent = inkCountText(opt);
            const fill = el.querySelector('.ink-slider-fill');
            if (fill) fill.style.width = inkSliderPct(opt) + '%';
        }
    });
    scrollInkFocus();
    updateInkImage();
}

/* ---- ability card deck (category tabs + locked-card feedback) ---- */
const deckWrap = document.getElementById('deck-wrap');

const DECK_CATS = {
    instinct: 'INSTINCT', combat: 'COMBAT', recovery: 'RECOVERY',
    defense: 'DEFENSE', frontier: 'FRONTIER',
};
const DECK_CAT_ORDER = ['all', 'instinct', 'combat', 'recovery', 'defense', 'frontier'];
let deckState = null; /* { data, cat } - cat survives the equip repaints */

/* A caller may ship its own tabs as data.cats = [{key,label},...]; without it
   the deck falls back to the built-in RDO ability-card categories. */
function deckCats() {
    const custom = deckState && deckState.data && deckState.data.cats;
    if (!Array.isArray(custom) || !custom.length) {
        return { labels: DECK_CATS, order: DECK_CAT_ORDER };
    }
    const labels = {};
    const order = ['all'];
    custom.forEach((c) => {
        if (!c || !c.key) return;
        labels[c.key] = c.label || String(c.key).toUpperCase();
        order.push(c.key);
    });
    return { labels, order };
}

function renderDeckTabs() {
    const tabs = document.getElementById('deck-cats');
    tabs.innerHTML = '';
    const { labels, order } = deckCats();
    order.forEach((key) => {
        const el = document.createElement('div');
        el.className = 'shop-cat' + (key === deckState.cat ? ' active' : '');
        el.textContent = key === 'all' ? 'ALL' : labels[key];
        el.addEventListener('click', () => {
            deckState.cat = key;
            renderDeckTabs();
            renderDeckCards();
        });
        tabs.appendChild(el);
    });
}

function renderDeckCards() {
    const data = deckState.data;
    const cardsEl = document.getElementById('deck-cards');
    cardsEl.innerHTML = '';
    let cards = data.cards || [];
    if (deckState.cat !== 'all') {
        cards = cards.filter((c) => (c.category || 'frontier') === deckState.cat);
    }
    cards.forEach((card) => {
        const el = document.createElement('div');
        el.className = 'deck-card cat-' + (card.category || 'frontier')
            + (card.equipped ? ' equipped' : '') + (card.locked ? ' locked' : '');

        const cat = document.createElement('div');
        cat.className = 'deck-cat';
        cat.textContent = deckCats().labels[card.category] || DECK_CATS[card.category] || 'FRONTIER';
        const glyph = document.createElement('div');
        glyph.className = 'deck-glyph';
        const _gsvg = iconSVG(card.glyph);
        if (_gsvg) glyph.innerHTML = _gsvg; else glyph.textContent = card.glyph || '✦';
        const name = document.createElement('div');
        name.className = 'deck-name';
        name.textContent = card.name;
        const desc = document.createElement('div');
        desc.className = 'deck-desc';
        desc.textContent = stripBr(card.desc || '');
        const tag = document.createElement('div');
        tag.className = 'deck-tag';
        tag.textContent = card.locked ? `REQUIRES LEVEL ${card.rank}` : (card.equipped ? 'EQUIPPED' : 'EQUIP');

        el.appendChild(cat); el.appendChild(glyph); el.appendChild(name); el.appendChild(desc); el.appendChild(tag);
        if (!card.locked) {
            el.addEventListener('click', () => NUI('perkToggle', { id: card.id }));
        } else {
            /* a locked card must SAY why instead of ignoring the click */
            el.addEventListener('click', () => addToast({
                title: `Requires Level ${card.rank}`,
                /* card.have lets a caller with more than one progression track
                   report the level that actually gates THIS card */
                subtitle: `You don't have the required level — you are level ${card.have != null ? card.have : (data.rank || 1)}.`,
                symbol: '✖',
                tone: 'red',
                duration: 3500,
            }));
        }
        cardsEl.appendChild(el);
    });
}

function renderDeck(data) {
    const slots = data.slots || { instinct: 1, passive: 3 };
    /* data.sub wins when the caller tracks something a single RANK can't say
       (pup-perks runs two independent progression tracks) */
    document.getElementById('deck-sub').innerHTML = data.sub ||
        (`RANK ${data.rank || 1} &mdash; INSTINCT <span class="gold">${data.instinctCount || 0}/${slots.instinct}</span>` +
         ` &mdash; PASSIVES <span class="gold">${data.passiveCount || 0}/${slots.passive}</span>`);

    let cat = deckState && deckState.cat ? deckState.cat : 'all';
    deckState = { data, cat };
    /* a previous consumer's tab must not survive into a deck that has no such
       category, or every card filters out and the deck looks empty */
    if (cat !== 'all' && !deckCats().order.includes(cat)) {
        cat = 'all';
        deckState.cat = cat;
    }
    renderDeckTabs();
    renderDeckCards();
}

function openDeck(data) {
    renderDeck(data);
    deckWrap.classList.remove('hidden');
}

window.addEventListener('keyup', (e) => {
    if (e.key !== 'Escape') return;
    if (appWrap && !appWrap.classList.contains('hidden')) {
        DBG('ESC -> app');
        appWrap.classList.add('hidden');
        NUI('appClose');
        return;
    }
    if (!inputWrap.classList.contains('hidden')) {
        DBG('ESC -> input');
        inputWrap.classList.add('hidden');
        NUI('inputCancel');
        return;
    }
    if (!shopWrap.classList.contains('hidden')) {
        DBG('ESC -> shop');
        shopWrap.classList.add('hidden');
        NUI('shopClose');
        return;
    }
    if (wardWrap && !wardWrap.classList.contains('hidden')) {
        DBG('ESC -> wardrobe');
        wardWrap.classList.add('hidden');
        NUI('wardrobeClose');
        return;
    }
    if (!listWrap.classList.contains('hidden')) {
        DBG('ESC -> list');
        closeListMenu(true);
        return;
    }
    if (!deckWrap.classList.contains('hidden')) {
        DBG('ESC -> deck');
        deckWrap.classList.add('hidden');
        NUI('deckClose');
        return;
    }
    if (!pmWrap.classList.contains('hidden')) {
        DBG('ESC -> pm');
        pmWrap.classList.add('hidden');
        NUI('pmClose');
        return;
    }
    /* ESC arrived but no main-chain panel is visible: the wheel/radial
       listeners may still catch it - if THEY don't either, this line is
       the smoking gun for a focus-holder with nothing on screen */
    DBG('ESC -> no main-chain panel visible');
});

/* ---- full-screen app / dashboard (data-driven; the OWNER resource drives
   every tab's contents). Layout: top bar (title + subtitle + red pill badge +
   close), a left nav rail of icon cards, and a scrolling content column that
   renders an ARRAY of typed BLOCKS. Nav/actions fire back to Lua; the owner
   answers with UpdateApp so it can load the clicked tab's data. Block types:
     heading { text, sub }
     stats   { items:[{value,label}] }                     - the 4 big cards
     glance  { title, cols:[{value,label}], link:{text,id}, spark }
     table   { title, link:{text,id}, columns:[{key,label}],
               rows:[{ cells:{ <key>:{ text, tone } } }, perPage] }
                                                           - tone: pos/neg/
               muted/badge-green/badge-red/badge-neutral/default. perPage > 0
               draws one page at a time with Prev/Next; the page is held in the
               DOM, so turning it costs no round trip and no re-render.
     ranks   { permKeys:[{key,label}], tax, ranks:[{ id, title, note, salary,
               tax, taxperiod, editable, perms:{ <key>:bool } }] }
                                                           - salary + Save +
               a row of toggle pills (on = red w/ check, off = outline w/ +).
               tax:true adds a TAX amount under the salary and a period button
               cycling daily/weekly/monthly; both ride along on rankSave.
     list    { items:[{ title, sub, actions:[{id,label,tone}] }] }
     actions { buttons:[{id,label,tone}] }                  - tone: red/green/ghost
   ---- */
const appWrap = document.getElementById('app-wrap');
let appState = null; /* { title, subtitle, badge, tabs, active, content } - kept so UpdateApp can swap active tab + content without a full reopen */

function appEl(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = text;
    return e;
}

/* sidebar icons reuse the ICON_SVG registry; anything unknown => a neutral dot */
function appIcon(name) {
    const svg = iconSVG(name);
    if (svg) return svg;
    return '<svg class="pup-svg" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="3.4"/></svg>';
}

/* a button used by the list/actions blocks (and glance/table links) */
function appActionBtn(btn, ctx) {
    const el = appEl('div', 'app-btn' + (btn.tone ? ' tone-' + btn.tone : ''), btn.label || '');
    el.addEventListener('click', () => NUI('appAction', { action: btn.id, data: ctx || {} }));
    return el;
}

function appLink(link, ctx) {
    const el = appEl('div', 'app-link', link.text || '');
    el.addEventListener('click', () => NUI('appAction', { action: link.id || 'link', data: ctx || {} }));
    return el;
}

function appHeadingBlock(b) {
    const wrap = appEl('div', 'app-heading');
    wrap.appendChild(appEl('div', 'app-heading-text', b.text || ''));
    if (b.sub) wrap.appendChild(appEl('div', 'app-heading-sub', b.sub));
    return wrap;
}

function appStatsBlock(b) {
    const grid = appEl('div', 'app-stats');
    (b.items || []).forEach((it) => {
        const card = appEl('div', 'app-stat-card');
        card.appendChild(appEl('div', 'app-stat-value', it.value !== undefined ? String(it.value) : ''));
        card.appendChild(appEl('div', 'app-stat-label', it.label || ''));
        grid.appendChild(card);
    });
    return grid;
}

/* a small decorative sparkline (fixed shape) for glance cards */
function appSparkSVG() {
    const vals = [12, 17, 14, 22, 19, 27, 24, 32, 29, 38];
    const n = vals.length, lo = 8, hi = 40, step = 100 / (n - 1);
    let d = '';
    vals.forEach((v, i) => {
        const x = (i * step).toFixed(1);
        const y = (40 - ((v - lo) / (hi - lo)) * 32 - 4).toFixed(1);
        d += (i === 0 ? 'M' : 'L') + x + ' ' + y + ' ';
    });
    const holder = document.createElement('div');
    holder.innerHTML = `<svg class="app-spark" viewBox="0 0 100 40" preserveAspectRatio="none">`
        + `<path class="app-spark-fill" d="${d}L100 40 L0 40 Z"/>`
        + `<path d="${d.trim()}"/></svg>`;
    return holder.firstElementChild;
}

function appGlanceBlock(b) {
    const card = appEl('div', 'app-card');
    if (b.title || (b.link && b.link.text)) {
        const head = appEl('div', 'app-card-head');
        if (b.title) head.appendChild(appEl('div', 'app-card-title', b.title));
        if (b.link && b.link.text) head.appendChild(appLink(b.link, { title: b.title }));
        card.appendChild(head);
    }
    const cols = appEl('div', 'app-glance-cols');
    (b.cols || []).forEach((c) => {
        const col = appEl('div', 'app-glance-col');
        col.appendChild(appEl('div', 'app-glance-value', c.value !== undefined ? String(c.value) : ''));
        col.appendChild(appEl('div', 'app-glance-label', c.label || ''));
        cols.appendChild(col);
    });
    card.appendChild(cols);
    if (b.spark) card.appendChild(appSparkSVG());
    return card;
}

const APP_TONE_PILL = { 'badge-green': 'pill-green', 'badge-red': 'pill-red', 'badge-neutral': 'pill-neutral' };
const APP_TONE_TD = { pos: 'tone-pos', neg: 'tone-neg', muted: 'tone-muted' };

function appTableBlock(b) {
    const card = appEl('div', 'app-card');
    if (b.title || (b.link && b.link.text)) {
        const head = appEl('div', 'app-card-head');
        if (b.title) head.appendChild(appEl('div', 'app-card-title', b.title));
        if (b.link && b.link.text) head.appendChild(appLink(b.link, { title: b.title }));
        card.appendChild(head);
    }
    const cols = b.columns || [];
    const table = appEl('table', 'app-table');
    const thead = appEl('thead');
    const htr = appEl('tr');
    cols.forEach((c) => htr.appendChild(appEl('th', null, c.label || '')));
    thead.appendChild(htr);
    table.appendChild(thead);

    /* paging: `perPage` splits a long table; the page lives in the DOM so
       Prev/Next never round-trips to Lua or resets the page */
    const allRows = b.rows || [];
    const perPage = Number(b.perPage) > 0 ? Number(b.perPage) : 0;
    const pages = perPage ? Math.max(1, Math.ceil(allRows.length / perPage)) : 1;
    let page = 0;

    const tbody = appEl('tbody');
    const drawRows = () => {
        tbody.textContent = '';
        const slice = perPage ? allRows.slice(page * perPage, (page + 1) * perPage) : allRows;
        slice.forEach((row) => {
        const tr = appEl('tr');
        cols.forEach((c) => {
            const cell = (row.cells && row.cells[c.key]) || {};
            const tone = cell.tone || 'default';
            const td = appEl('td');
            if (APP_TONE_PILL[tone]) {
                td.appendChild(appEl('span', 'app-pill ' + APP_TONE_PILL[tone], cell.text || ''));
            } else {
                const txt = cell.text !== undefined && cell.text !== null ? String(cell.text) : '';
                if (cell.copy && txt && txt !== '-') {
                    // explicit copy affordance: the text plus a click-to-copy icon.
                    // Text lives in its own span so the "copied!" feedback cannot
                    // wipe the icon out of the cell.
                    td.classList.add('app-td-copy');
                    const label = appEl('span', 'app-td-text', txt);
                    const btn = appEl('span', 'app-copy-btn');
                    btn.title = 'Copy';
                    btn.innerHTML =
                        '<svg viewBox="0 0 24 24" aria-hidden="true">' +
                        '<rect x="9" y="9" width="11" height="11" rx="2"></rect>' +
                        '<path d="M5 15V5a2 2 0 0 1 2-2h10"></path>' +
                        '</svg>';
                    td.appendChild(label);
                    td.appendChild(btn);
                } else {
                    td.textContent = txt;
                }
                if (APP_TONE_TD[tone]) td.classList.add(APP_TONE_TD[tone]);
            }
            tr.appendChild(td);
        });
        tbody.appendChild(tr);
        });
    };
    drawRows();
    table.appendChild(tbody);
    card.appendChild(table);

    if (pages > 1) {
        const bar = appEl('div', 'app-pager');
        const prev = appEl('div', 'app-btn app-pager-btn', 'PREV');
        const label = appEl('div', 'app-pager-label', '');
        const next = appEl('div', 'app-btn app-pager-btn', 'NEXT');
        const sync = () => {
            label.textContent = 'Page ' + (page + 1) + ' of ' + pages;
            prev.classList.toggle('is-off', page <= 0);
            next.classList.toggle('is-off', page >= pages - 1);
        };
        prev.addEventListener('click', () => { if (page > 0) { page--; drawRows(); sync(); } });
        next.addEventListener('click', () => { if (page < pages - 1) { page++; drawRows(); sync(); } });
        sync();
        bar.appendChild(prev);
        bar.appendChild(label);
        bar.appendChild(next);
        card.appendChild(bar);
    }
    return card;
}

/* Click any table cell to copy its text (Discord IDs, char ids, container ids).
   In-game text is not selectable, so copy-on-click is the only practical way to
   get an id out of the panel and into Discord.
   navigator.clipboard needs a secure context, which NUI is not, so fall back to
   the textarea + execCommand trick. The panel already holds NUI focus, so the
   document is focused and execCommand works. */
function appCopyText(text) {
    if (!text) return false;
    try {
        const ta = document.createElement('textarea');
        ta.value = text;
        ta.setAttribute('readonly', '');
        ta.style.position = 'fixed';
        ta.style.opacity = '0';
        document.body.appendChild(ta);
        ta.select();
        ta.setSelectionRange(0, ta.value.length);
        const ok = document.execCommand('copy');
        document.body.removeChild(ta);
        return ok;
    } catch (e) {
        return false;
    }
}

/* only cells that opted in with `copy = true` are copyable */
document.addEventListener('click', (e) => {
    const td = e.target && e.target.closest ? e.target.closest('.app-table td.app-td-copy') : null;
    if (!td) return;

    // the text lives in .app-td-text so the icon survives the confirmation swap
    const label = td.querySelector('.app-td-text') || td;
    const text = (label.textContent || '').trim();
    if (!text || text === '-' || text === 'not linked' || text === 'copied!') return;
    if (!appCopyText(text)) return;

    // brief inline confirmation - no toast, the panel owns the screen
    if (label.dataset.prevText === undefined) label.dataset.prevText = text;
    label.textContent = 'copied!';
    td.classList.add('app-td-copied');
    setTimeout(() => {
        label.textContent = label.dataset.prevText;
        td.classList.remove('app-td-copied');
        delete label.dataset.prevText;
    }, 900);
});

function appRanksBlock(b) {
    const wrap = appEl('div', 'app-ranks');
    const permKeys = b.permKeys || [];
    (b.ranks || []).forEach((rank) => {
        const card = appEl('div', 'app-card app-rank');
        const head = appEl('div', 'app-rank-head');
        const titles = appEl('div', 'app-rank-titles');
        titles.appendChild(appEl('div', 'app-rank-title', rank.title || ''));
        if (rank.note) titles.appendChild(appEl('div', 'app-rank-note', rank.note));
        head.appendChild(titles);

        /* Fields are a 3-column GRID:
               SALARY  [ input ]  [ SAVE   ]
               TAX     [ input ]  [ WEEKLY ]
           Both inputs share a column, and SAVE sits directly above the period
           button instead of floating off to the side of the pair. Grid placement
           follows DOM order, so the cells are appended row by row - which is why
           SAVE is built here, before the tax row, rather than further down.
           With tax off the grid is one row and lays out exactly as it always did. */
        const salWrap = appEl('div', 'app-rank-salary');
        const fields = appEl('div', 'app-rank-fields');

        fields.appendChild(appEl('span', 'app-rank-salary-label', 'SALARY'));
        const input = appEl('input', 'app-salary-input');
        input.type = 'number';
        input.value = rank.salary !== undefined ? rank.salary : 0;
        if (rank.editable === false) input.disabled = true;
        fields.appendChild(input);

        /* tax: drawn only when `b.tax` is on; the period is a cycle button
           because the RDR2 font styling does not carry to a native <select> */
        const PERIODS = ['daily', 'weekly', 'monthly'];
        let taxInput = null;
        let period = PERIODS.indexOf(String(rank.taxperiod || 'weekly').toLowerCase());
        if (period < 0) period = 1;

        /* declared before the handler that closes over them */
        const pillState = {};
        const saveBtn = appEl('div', 'app-btn tone-red app-rank-save', 'SAVE');
        fields.appendChild(saveBtn);

        if (b.tax) {
            fields.appendChild(appEl('span', 'app-rank-salary-label', 'TAX'));
            taxInput = appEl('input', 'app-salary-input');
            taxInput.type = 'number';
            taxInput.min = '0';
            taxInput.value = rank.tax !== undefined && rank.tax !== null ? rank.tax : 0;
            if (rank.editable === false) taxInput.disabled = true;
            fields.appendChild(taxInput);

            const periodBtn = appEl('div', 'app-btn app-period-btn', PERIODS[period].toUpperCase());
            if (rank.editable !== false) {
                periodBtn.addEventListener('click', () => {
                    period = (period + 1) % PERIODS.length;
                    periodBtn.textContent = PERIODS[period].toUpperCase();
                });
            } else {
                periodBtn.classList.add('is-off');
            }
            fields.appendChild(periodBtn);
        }
        salWrap.appendChild(fields);
        saveBtn.addEventListener('click', () => {
            const perms = {};
            permKeys.forEach((pk) => { perms[pk.key] = !!pillState[pk.key]; });
            const payload = { id: rank.id, salary: Number(input.value) || 0, perms };
            if (taxInput) {
                payload.tax = Math.max(0, Number(taxInput.value) || 0);
                payload.taxperiod = PERIODS[period];
            }
            NUI('appAction', { action: 'rankSave', data: payload });
        });
        head.appendChild(salWrap);
        card.appendChild(head);

        const perms = appEl('div', 'app-perms');
        permKeys.forEach((pk) => {
            const on = !!(rank.perms && rank.perms[pk.key]);
            pillState[pk.key] = on;
            const pill = appEl('div', 'app-perm' + (on ? ' on' : ''));
            const mark = appEl('span', 'app-perm-mark');
            mark.innerHTML = on ? iconSVG('check') : '+';
            pill.appendChild(mark);
            pill.appendChild(appEl('span', 'app-perm-label', pk.label || pk.key));
            if (rank.editable !== false) {
                pill.addEventListener('click', () => {
                    const now = !pill.classList.contains('on');
                    pill.classList.toggle('on', now);
                    pillState[pk.key] = now;
                    mark.innerHTML = now ? iconSVG('check') : '+';
                });
            }
            perms.appendChild(pill);
        });
        card.appendChild(perms);
        wrap.appendChild(card);
    });
    return wrap;
}

function appListBlock(b) {
    const wrap = appEl('div', 'app-list');
    (b.items || []).forEach((it) => {
        const row = appEl('div', 'app-card app-list-row');
        if (it.img) {
            /* item/weapon icon, e.g. nui://vorp_inventory/html/img/items/<name>.png */
            const im = document.createElement('img');
            im.className = 'app-list-img';
            im.src = it.img;
            im.onerror = function () { im.remove(); }; /* missing art: drop silently */
            row.appendChild(im);
        }
        const main = appEl('div', 'app-list-main');
        main.appendChild(appEl('div', 'app-list-title', it.title || ''));
        if (it.sub) main.appendChild(appEl('div', 'app-list-sub', it.sub));

        /* optional REQUIREMENTS strip: it.mats = [{ img, amount, label }, ...].
           Built for crafting bills - "3x Iron Bar, 3x Shell Casing" reads as a
           wall of text, where the icons are recognisable at a glance.
           Each entry falls back to its label if the art is missing, so an item
           with no png still shows what it needs rather than a broken image. */
        if (Array.isArray(it.mats) && it.mats.length) {
            const strip = appEl('div', 'app-list-mats');
            it.mats.forEach((m) => {
                if (!m) return;
                const cell = appEl('div', 'app-list-mat');
                const name = m.label || '?';
                cell.title = (m.amount ? m.amount + ' x ' : '') + name;
                if (m.img) {
                    const mi = document.createElement('img');
                    mi.className = 'app-list-mat-img';
                    mi.src = m.img;
                    mi.alt = '';
                    /* no art: drop the icon; the name text below still spells
                       out the requirement so nothing is silently lost */
                    mi.onerror = function () { mi.remove(); };
                    cell.appendChild(mi);
                }
                /* the item name always shows next to the icon, not only on hover */
                if (m.amount) cell.appendChild(appEl('span', 'app-list-mat-qty', m.amount + 'x'));
                cell.appendChild(appEl('span', 'app-list-mat-label', name));
                strip.appendChild(cell);
            });
            main.appendChild(strip);
        }

        row.appendChild(main);
        if (it.actions && it.actions.length) {
            const acts = appEl('div', 'app-list-actions');
            it.actions.forEach((a) => acts.appendChild(appActionBtn(a, { title: it.title })));
            row.appendChild(acts);
        }
        wrap.appendChild(row);
    });
    return wrap;
}

function appActionsBlock(b) {
    const wrap = appEl('div', 'app-actions');
    (b.buttons || []).forEach((btn) => wrap.appendChild(appActionBtn(btn, {})));
    return wrap;
}

/* search { id, value, placeholder }
   A text field that filters in place, instead of swapping the whole app out for
   the modal input panel. The app already owns the keyboard (PanelOpen('app')
   takes focus without keepInput), so typing lands here. Keystrokes are debounced
   into ONE appAction carrying { value }, and renderAppContent restores focus and
   the caret afterwards - without that the re-render would eat every letter. */
function appSearchBlock(b) {
    const wrap = appEl('div', 'app-search');
    const inp = document.createElement('input');
    inp.type = 'text';
    inp.className = 'app-search-input';
    inp.spellcheck = false;
    inp.autocomplete = 'off';
    inp.placeholder = b.placeholder || 'Search...';
    inp.value = b.value || '';
    inp.dataset.searchId = b.id || 'search';
    let timer = null;
    inp.addEventListener('input', () => {
        clearTimeout(timer);
        const v = inp.value;
        timer = setTimeout(() => NUI('appAction', { action: b.id || 'search', data: { value: v } }), 220);
    });
    /* Enter should not bubble to anything that might treat it as a menu pick */
    inp.addEventListener('keydown', (e) => { if (e.key === 'Enter') e.preventDefault(); });
    wrap.appendChild(inp);
    return wrap;
}

/* map { title, markers:[{x, y, label, sub, color, mine, radiusM}] }
   A read-only world map (built for the gang panel's Territory tab). Uses the
   SAME calibration as vorp_admin's live map and kibook/webmap's rdr3 map.jpg,
   loaded from its public GitHub URL (see style.css). Circles are influence radii
   in METRES, converted with the same world-width the calibration defines.
   Drag to pan; opens centred on the caller's own marker. */
const APP_MAP_W = 1000, APP_MAP_H = 750; /* half of vorp_admin's 2000x1500 */
const APP_WM = { radius: 16000, xOff: 8515, yOff: 10850, w: 11820, h: 8660 };
function appWorldToMap(x, y) {
    return [
        ((x + APP_WM.radius - APP_WM.xOff) / APP_WM.w) * APP_MAP_W,
        APP_MAP_H - ((y + APP_WM.radius - APP_WM.yOff) / APP_WM.h) * APP_MAP_H,
    ];
}
function appMapBlock(b) {
    const card = appEl('div', 'app-card app-map-card');
    if (b.title) {
        const head = appEl('div', 'app-card-head');
        head.appendChild(appEl('div', 'app-card-title', b.title));
        card.appendChild(head);
    }
    const frame = appEl('div', 'app-map-frame' + (b.tall ? ' tall' : ''));
    const world = appEl('div', 'app-map-world');
    world.style.width = APP_MAP_W + 'px';
    world.style.height = APP_MAP_H + 'px';

    (b.markers || []).forEach((m) => {
        const [mx, my] = appWorldToMap(Number(m.x) || 0, Number(m.y) || 0);
        if (m.radiusM) {
            /* metres -> map px through the calibrated world width. FILLED like
               a turf map - the circle IS the statement. */
            const d = Math.max(14, (m.radiusM / APP_WM.w) * APP_MAP_W * 2);
            const c = appEl('div', 'app-map-circle' + (m.mine ? ' mine' : ''));
            c.style.left = (mx - d / 2) + 'px';
            c.style.top = (my - d / 2) + 'px';
            c.style.width = d + 'px';
            c.style.height = d + 'px';
            if (m.color) {
                c.style.borderColor = m.color;
                c.style.background = m.color + '59'; /* ~35% fill */
            }
            world.appendChild(c);
        }
        /* centred BADGE: tag on top, points under it (BCM / 18 POINTS style) */
        const tag = appEl('div', 'app-map-badge' + (m.mine ? ' mine' : ''));
        tag.style.left = mx + 'px';
        tag.style.top = my + 'px';
        if (m.color) tag.style.borderColor = m.color;
        tag.appendChild(appEl('div', 'app-map-badge-name', m.label || '?'));
        if (m.sub) tag.appendChild(appEl('div', 'app-map-badge-sub', m.sub));
        if (m.foot) tag.appendChild(appEl('div', 'app-map-badge-foot', m.foot));
        world.appendChild(tag);
    });

    /* zoom buttons overlay */
    const zoom = appEl('div', 'app-map-zoom');
    const zin = appEl('div', 'app-map-zbtn', '+');
    const zout = appEl('div', 'app-map-zbtn', '−');
    zoom.appendChild(zin);
    zoom.appendChild(zout);

    frame.appendChild(world);
    frame.appendChild(zoom);
    card.appendChild(frame);

    /* pan/zoom state - translate+scale, the same scheme the admin live map
       uses. Badges counter-scale through --inv so they stay readable. */
    const view = { x: 0, y: 0, s: 1 };
    const apply = () => {
        const vw = frame.clientWidth || 1, vh = frame.clientHeight || 1;
        const minS = Math.min(vw / APP_MAP_W, vh / APP_MAP_H) * 0.95;
        view.s = Math.min(5, Math.max(minS, view.s));
        view.x = Math.min(80, Math.max(vw - APP_MAP_W * view.s - 80, view.x));
        view.y = Math.min(80, Math.max(vh - APP_MAP_H * view.s - 80, view.y));
        world.style.transform = 'translate(' + view.x + 'px, ' + view.y + 'px) scale(' + view.s + ')';
        world.style.setProperty('--inv', String(1 / view.s));
    };

    let drag = null;
    frame.addEventListener('mousedown', (e) => {
        if (e.target === zin || e.target === zout) return;
        drag = { x: e.clientX, y: e.clientY };
        e.preventDefault();
    });
    window.addEventListener('mouseup', () => { drag = null; });
    frame.addEventListener('mousemove', (e) => {
        if (!drag) return;
        view.x += e.clientX - drag.x;
        view.y += e.clientY - drag.y;
        drag = { x: e.clientX, y: e.clientY };
        apply();
    });
    const zoomAt = (mx, my, factor) => {
        const prev = view.s;
        view.s *= factor;
        apply();
        view.x = mx - (mx - view.x) * (view.s / prev);
        view.y = my - (my - view.y) * (view.s / prev);
        apply();
    };
    frame.addEventListener('wheel', (e) => {
        e.preventDefault();
        const rect = frame.getBoundingClientRect();
        zoomAt(e.clientX - rect.left, e.clientY - rect.top, e.deltaY < 0 ? 1.2 : 1 / 1.2);
    }, { passive: false });
    zin.addEventListener('click', () => zoomAt(frame.clientWidth / 2, frame.clientHeight / 2, 1.3));
    zout.addEventListener('click', () => zoomAt(frame.clientWidth / 2, frame.clientHeight / 2, 1 / 1.3));

    /* open centred on the viewer's own turf (or fit the whole map) */
    setTimeout(() => {
        const vw = frame.clientWidth || 1, vh = frame.clientHeight || 1;
        const focus = (b.markers || []).find((m) => m.mine);
        if (focus) {
            view.s = 1.6;
            const [fx, fy] = appWorldToMap(Number(focus.x) || 0, Number(focus.y) || 0);
            view.x = vw / 2 - fx * view.s;
            view.y = vh / 2 - fy * view.s;
        } else {
            view.s = 0.01; /* apply() clamps up to fit-the-frame */
            view.x = 0; view.y = 0;
        }
        apply();
    }, 0);

    return card;
}

/* ---- crafting blocks ----
   grid     { items:[{ img, label, count, sub, dim, sel, id }] }
   progress { items:[{ label, sub, value 0..1, right, img, done, actions }] }
   chips    { items:[{ id, label, active, count }] }
   stepper  { id, label, value, min, max, step, buttons:[{id,label,tone}] }
   bill     { items:[{ img, label, have, need, tool, note }] }
   hero     { img, title, sub, tags:[string] }
   split    { left:[blocks], right:[blocks], side:'wide' }
   note     { text }
   ---------------------------------------------- */

/* a plain line of prose where a list would otherwise be empty */
function appNoteBlock(b) {
    return appEl('div', 'app-note', b.text || '');
}

/* an item tile: picture, name, and a count badge in the corner */
function appGridBlock(b) {
    const grid = appEl('div', 'app-grid');
    (b.items || []).forEach((it) => {
        const cell = appEl('div', 'app-grid-cell' + (it.dim ? ' is-dim' : '')
            + (it.sel ? ' is-sel' : ''));
        const art = appEl('div', 'app-grid-art');
        if (it.img) {
            const img = document.createElement('img');
            img.src = it.img;
            /* a missing item png must not leave a broken-image glyph */
            img.onerror = () => { img.remove(); art.classList.add('no-art'); };
            art.appendChild(img);
        } else {
            art.classList.add('no-art');
        }
        if (it.count !== undefined && it.count !== null) {
            art.appendChild(appEl('div', 'app-grid-count', 'x' + it.count));
        }
        cell.appendChild(art);
        cell.appendChild(appEl('div', 'app-grid-label', it.label || ''));
        if (it.sub) cell.appendChild(appEl('div', 'app-grid-sub', it.sub));
        if (it.id) {
            cell.classList.add('is-clickable');
            cell.addEventListener('click', () => NUI('appAction', { action: it.id, data: {} }));
        }
        grid.appendChild(cell);
    });
    return grid;
}

/* last width per row id: the tab rebuilds every second, and a fresh element has
   nothing to transition FROM, so without this the bar would step, not glide */
const progLastPct = {};

/* a row with a filling bar: what is being made and how far along it is */
function appProgressBlock(b) {
    const wrap = appEl('div', 'app-progress');
    (b.items || []).forEach((it) => {
        const row = appEl('div', 'app-prog-row' + (it.done ? ' is-done' : ''));

        if (it.img) {
            const art = appEl('div', 'app-prog-art');
            const img = document.createElement('img');
            img.src = it.img;
            img.onerror = () => { img.remove(); art.classList.add('no-art'); };
            art.appendChild(img);
            row.appendChild(art);
        }

        const mid = appEl('div', 'app-prog-main');
        const head = appEl('div', 'app-prog-head');
        head.appendChild(appEl('div', 'app-prog-label', it.label || ''));
        if (it.right) head.appendChild(appEl('div', 'app-prog-right', it.right));
        mid.appendChild(head);

        const track = appEl('div', 'app-prog-track');
        const fill = appEl('div', 'app-prog-fill');
        let v = Number(it.value);
        if (!isFinite(v)) v = 0;
        const pct = Math.max(0, Math.min(1, v)) * 100;
        /* start where the last render left off, then glide to the new value */
        const key = it.id !== undefined && it.id !== null ? String(it.id) : null;
        const from = key !== null && progLastPct[key] !== undefined ? progLastPct[key] : pct;
        fill.style.width = from + '%';
        if (key !== null) progLastPct[key] = pct;
        if (from !== pct) requestAnimationFrame(() => { fill.style.width = pct + '%'; });
        track.appendChild(fill);
        mid.appendChild(track);

        if (it.sub) mid.appendChild(appEl('div', 'app-prog-sub', it.sub));
        row.appendChild(mid);

        if (Array.isArray(it.actions) && it.actions.length) {
            const acts = appEl('div', 'app-prog-actions');
            it.actions.forEach((btn) => acts.appendChild(appActionBtn(btn, {})));
            row.appendChild(acts);
        }
        wrap.appendChild(row);
    });
    return wrap;
}

/* the filter pills across the top of a recipe list */
function appChipsBlock(b) {
    const row = appEl('div', 'app-chips');
    (b.items || []).forEach((it) => {
        const chip = appEl('div', 'app-chip' + (it.active ? ' is-active' : ''), it.label || '');
        if (it.count !== undefined && it.count !== null) {
            chip.appendChild(appEl('span', 'app-chip-count', String(it.count)));
        }
        chip.addEventListener('click', () => NUI('appAction', { action: it.id, data: {} }));
        row.appendChild(chip);
    });
    return row;
}

/* a quantity picker: minus, the number, plus, then the confirm buttons */
function appStepperBlock(b) {
    const wrap = appEl('div', 'app-stepper');
    if (b.label) wrap.appendChild(appEl('div', 'app-stepper-label', b.label));

    const min = Number(b.min) || 1;
    const max = Number(b.max) || 99;
    const step = Number(b.step) || 1;
    let value = Math.max(min, Math.min(max, Number(b.value) || min));

    const box = appEl('div', 'app-stepper-box');
    const minus = appEl('div', 'app-stepper-btn', '-');
    const num = appEl('div', 'app-stepper-value', String(value));
    const plus = appEl('div', 'app-stepper-btn', '+');

    /* the number is held in the DOM, so nudging it costs no round trip; only
       the confirm buttons tell Lua, and they carry the amount with them */
    const set = (next) => {
        value = Math.max(min, Math.min(max, next));
        num.textContent = String(value);
    };
    minus.addEventListener('click', () => set(value - step));
    plus.addEventListener('click', () => set(value + step));

    box.appendChild(minus);
    box.appendChild(num);
    box.appendChild(plus);
    wrap.appendChild(box);

    if (Array.isArray(b.buttons) && b.buttons.length) {
        const acts = appEl('div', 'app-stepper-actions');
        b.buttons.forEach((btn) => {
            const el = appEl('div', 'app-btn' + (btn.tone ? ' tone-' + btn.tone : ''), btn.label || '');
            el.addEventListener('click', () => NUI('appAction', {
                action: btn.id, data: { value: value, id: b.id },
            }));
            acts.appendChild(el);
        });
        wrap.appendChild(acts);
    }
    return wrap;
}

/* the ingredient list: a dot per line, green when you hold enough */
function appBillBlock(b) {
    const wrap = appEl('div', 'app-bill');
    (b.items || []).forEach((it) => {
        const have = Number(it.have) || 0;
        const need = Number(it.need) || 0;
        const ok = have >= need;
        const row = appEl('div', 'app-bill-row' + (ok ? ' is-ok' : ' is-short')
            + (it.tool ? ' is-tool' : ''));

        if (it.img) {
            const art = appEl('div', 'app-bill-art');
            const img = document.createElement('img');
            img.src = it.img;
            img.onerror = () => { img.remove(); art.classList.add('no-art'); };
            art.appendChild(img);
            row.appendChild(art);
        }
        row.appendChild(appEl('span', 'app-bill-dot'));
        row.appendChild(appEl('span', 'app-bill-label', it.label || ''));
        /* a tool shows what it is, not a tally: it.note carries "held" or wear */
        row.appendChild(appEl('span', 'app-bill-count', it.note || (have + ' / ' + need)));
        wrap.appendChild(row);
    });
    return wrap;
}

/* hero: the big item portrait at the top of a detail panel */
function appHeroBlock(b) {
    const wrap = appEl('div', 'app-hero');
    const art = appEl('div', 'app-hero-art');
    if (b.img) {
        const img = document.createElement('img');
        img.src = b.img;
        img.onerror = () => { img.remove(); art.classList.add('no-art'); };
        art.appendChild(img);
    } else {
        art.classList.add('no-art');
    }
    wrap.appendChild(art);
    wrap.appendChild(appEl('div', 'app-hero-title', b.title || ''));
    if (b.sub) wrap.appendChild(appEl('div', 'app-hero-sub', b.sub));
    if (Array.isArray(b.tags) && b.tags.length) {
        const tags = appEl('div', 'app-hero-tags');
        b.tags.forEach((t) => { if (t) tags.appendChild(appEl('span', 'app-hero-tag', String(t))); });
        wrap.appendChild(tags);
    }
    return wrap;
}

/* split: browse on the left, a pinned panel on the right; both hold blocks */
function appSplitBlock(b) {
    const wrap = appEl('div', 'app-split' + (b.side ? ' side-' + b.side : ''));
    const left = appEl('div', 'app-split-main');
    const right = appEl('div', 'app-split-side');
    appRenderBlocks(b.left, left);
    appRenderBlocks(b.right, right);
    wrap.appendChild(left);
    wrap.appendChild(right);
    return wrap;
}

const APP_BLOCKS = {
    heading: appHeadingBlock,
    stats: appStatsBlock,
    glance: appGlanceBlock,
    table: appTableBlock,
    ranks: appRanksBlock,
    list: appListBlock,
    map: appMapBlock,
    actions: appActionsBlock,
    search: appSearchBlock,
    grid: appGridBlock,
    progress: appProgressBlock,
    chips: appChipsBlock,
    stepper: appStepperBlock,
    bill: appBillBlock,
    hero: appHeroBlock,
    split: appSplitBlock,
    note: appNoteBlock,
};

/* one block list into one host; split calls it per column, so lists nest */
function appRenderBlocks(content, host) {
    (content || []).forEach((b) => {
        const fn = b && APP_BLOCKS[b.type];
        if (fn) host.appendChild(fn(b));
    });
}

function renderAppContent(content) {
    const host = document.getElementById('app-content');

    /* a live search re-renders on every keystroke; carry the caret across so the
       field the player is typing in survives being rebuilt underneath them */
    const prev = host.querySelector('.app-search-input');
    const keep = (prev && document.activeElement === prev)
        ? { id: prev.dataset.searchId, value: prev.value, start: prev.selectionStart, end: prev.selectionEnd }
        : null;
    const prevScroll = host.scrollTop;

    host.innerHTML = '';
    appRenderBlocks(content, host);

    if (keep) {
        const next = host.querySelector('.app-search-input[data-search-id="' + keep.id + '"]');
        if (next) {
            next.value = keep.value;
            next.focus();
            try { next.setSelectionRange(keep.start, keep.end); } catch (e) { /* not selectable */ }
            host.scrollTop = prevScroll;
            return;
        }
    }
    host.scrollTop = 0;
}

function renderAppNav(tabs, active) {
    const nav = document.getElementById('app-nav');
    nav.innerHTML = '';
    (tabs || []).forEach((t) => {
        /* a tab entry may instead be a section header: { section: 'AMMO' } */
        if (t && t.section) {
            nav.appendChild(appEl('div', 'app-nav-section', t.section));
            return;
        }
        const item = appEl('div', 'app-nav-item' + (t.id === active ? ' active' : ''));
        item.dataset.tab = t.id;
        const ico = appEl('div', 'app-nav-icon');
        ico.innerHTML = appIcon(t.icon);
        item.appendChild(ico);
        item.appendChild(appEl('div', 'app-nav-label', t.label || t.id));
        item.addEventListener('click', () => {
            /* highlight immediately for responsiveness; the owner still owns
               the switch and answers with UpdateApp to load the tab's data */
            nav.querySelectorAll('.app-nav-item').forEach((n) => n.classList.remove('active'));
            item.classList.add('active');
            if (appState) appState.active = t.id;
            NUI('appNav', { tab: t.id });
        });
        nav.appendChild(item);
    });
}

function openApp(data) {
    appState = data || {};
    document.getElementById('app-title').textContent = appState.title || '';
    const sub = document.getElementById('app-subtitle');
    sub.textContent = appState.subtitle || '';
    sub.style.display = appState.subtitle ? '' : 'none';
    const badge = document.getElementById('app-badge');
    badge.textContent = appState.badge || '';
    badge.style.display = appState.badge ? '' : 'none';
    renderAppNav(appState.tabs || [], appState.active);
    renderAppContent(appState.content || []);
    appWrap.classList.remove('hidden');
}

/* swap the active tab + content in place (after a nav round-trip) without
   reopening; tabs/title are kept from the last openApp.

   subtitle and badge are updatable too - each only when the caller actually
   sends the field, so a caller that omits it keeps whatever openApp set rather
   than having it blanked. Added for a header that has to react to something the
   player just did (vorp_fishing shows an outstanding-rewards count there, and it
   has to drop as they claim); before this, updateApp silently ignored both and
   the header stayed frozen at whatever it opened with. */
function updateApp(data) {
    if (!appState) return;
    if (data.active !== undefined) {
        appState.active = data.active;
        document.getElementById('app-nav').querySelectorAll('.app-nav-item').forEach((n) => {
            n.classList.toggle('active', n.dataset.tab === String(data.active));
        });
    }
    if (data.subtitle !== undefined) {
        appState.subtitle = data.subtitle;
        const sub = document.getElementById('app-subtitle');
        sub.textContent = data.subtitle || '';
        sub.style.display = data.subtitle ? '' : 'none';
    }
    if (data.badge !== undefined) {
        appState.badge = data.badge;
        const badge = document.getElementById('app-badge');
        badge.textContent = data.badge || '';
        badge.style.display = data.badge ? '' : 'none';
    }
    if (data.content !== undefined) {
        appState.content = data.content;
        renderAppContent(data.content);
    }
}

function hideApp() {
    appWrap.classList.add('hidden');
    appState = null;
}

document.getElementById('app-close').addEventListener('click', () => {
    appWrap.classList.add('hidden');
    NUI('appClose');
});

/* ---- floating 3D world labels (client/world3d.lua) ----
   One batched 'world3d' message per frame while any point is in range:
   [{ id, x, y (0-1 screen), text, icon, a (alpha/scale by distance) }].
   Pills are keyed by id and REUSED across frames - only the transform
   moves per frame; text/icon rewrites are skipped unless they changed. */
const world3dWrap = document.getElementById('world3d-wrap');
const world3dPills = {}; // id -> element

function world3dRender(data) {
    const items = data.items || [];
    const seen = {};
    items.forEach((p) => {
        seen[p.id] = true;
        let el = world3dPills[p.id];
        if (!el) {
            el = document.createElement('div');
            el.className = 'w3d-pill';
            // the body wrapper can be tilted; the pill's own transform is rewritten every frame
            el.innerHTML = '<span class="w3d-body"><span class="w3d-icon"></span><span class="w3d-text"></span></span>';
            world3dPills[p.id] = el;
            world3dWrap.appendChild(el);
        }
        const look = String(p.style || '').replace(/[^a-z]/g, '');
        if ((el.dataset.look || '') !== look) {
            el.dataset.look = look;
            el.className = look ? 'w3d-pill w3d-' + look : 'w3d-pill';
        }
        if (el.dataset.icon !== String(p.icon || '')) {
            el.dataset.icon = String(p.icon || '');
            const iconEl = el.querySelector('.w3d-icon');
            const svg = iconSVG(p.icon);
            if (svg) iconEl.innerHTML = svg; else iconEl.textContent = p.icon || '';
        }
        if (el.dataset.text !== String(p.text || '')) {
            el.dataset.text = String(p.text || '');
            el.querySelector('.w3d-text').textContent = p.text || '';
        }
        const a = (typeof p.a === 'number') ? Math.max(0, Math.min(1, p.a)) : 1;
        el.style.transform = `translate(calc(${(p.x * 100).toFixed(2)}vw - 50%), calc(${(p.y * 100).toFixed(2)}vh - 50%)) scale(${(0.75 + 0.25 * a).toFixed(3)})`;
        el.style.opacity = a.toFixed(2);
    });
    Object.keys(world3dPills).forEach((id) => {
        if (!seen[id]) { world3dPills[id].remove(); delete world3dPills[id]; }
    });
    world3dWrap.classList.toggle('hidden', items.length === 0);
}

function world3dHide() {
    world3dWrap.classList.add('hidden');
    Object.keys(world3dPills).forEach((id) => { world3dPills[id].remove(); delete world3dPills[id]; });
}

/* ---- scene labels (client/world3d.lua DrawSceneLabels) ----
   One 'sceneLabels' message per frame: [{ id, x, y, segs:[{t,r,g,b}], scale, back, a, font }].
   Elements are keyed by id and reused; the text is rebuilt only when its segments change. */
const sceneWrap = document.getElementById('scene-wrap');
const sceneLabels = {}; // id -> element

function sceneLabelsRender(data) {
    const items = data.items || [];
    const seen = {};
    items.forEach((p) => {
        seen[p.id] = true;
        let el = sceneLabels[p.id];
        if (!el) {
            el = document.createElement('div');
            el.className = 'scene-label';
            sceneLabels[p.id] = el;
            sceneWrap.appendChild(el);
        }
        const key = JSON.stringify(p.segs || []) + '|' + p.font;
        if (el.dataset.key !== key) {
            el.dataset.key = key;
            el.textContent = '';
            (p.segs || []).forEach((s) => {
                const span = document.createElement('span');
                span.textContent = s.t || '';
                span.style.color = `rgb(${s.r | 0}, ${s.g | 0}, ${s.b | 0})`;
                el.appendChild(span);
            });
            el.className = 'scene-label sf' + (Number.isInteger(p.font) ? p.font : 1);
        }
        const a = (typeof p.a === 'number') ? Math.max(0, Math.min(1, p.a)) : 1;
        const back = (typeof p.back === 'number') ? Math.max(0, Math.min(1, p.back)) : 0;
        el.style.fontSize = ((Number(p.scale) || 0.3) * 6.2).toFixed(2) + 'vh';
        el.style.background = back > 0 ? `rgba(35, 35, 35, ${(back * a).toFixed(2)})` : 'transparent';
        el.style.transform = `translate(calc(${(p.x * 100).toFixed(2)}vw - 50%), calc(${(p.y * 100).toFixed(2)}vh - 50%))`;
        el.style.opacity = a.toFixed(2);
    });
    Object.keys(sceneLabels).forEach((id) => {
        if (!seen[id]) { sceneLabels[id].remove(); delete sceneLabels[id]; }
    });
    sceneWrap.classList.toggle('hidden', items.length === 0);
}

function sceneLabelsHide() {
    sceneWrap.classList.add('hidden');
    Object.keys(sceneLabels).forEach((id) => { sceneLabels[id].remove(); delete sceneLabels[id]; });
}

/* focus-holding panel wraps, used by the Lua desync watchdog */
const FOCUS_PANEL_IDS = ['app-wrap', 'shop-wrap', 'ward-wrap', 'list-wrap', 'pm-wrap', 'deck-wrap', 'wheel-wrap', 'radial-wrap', 'input-wrap'];

/* actions too chatty to trace (world3d fires EVERY frame) */
const DBG_QUIET_ACTIONS = {
    pupSync: true, hud: true, toast: true, rank: true, honor: true,
    world3d: true, world3dHide: true, sceneLabels: true, sceneLabelsHide: true,
};

window.addEventListener('message', ({ data: msg }) => {
    if (!msg || !msg.action) return;
    if (!DBG_QUIET_ACTIONS[msg.action]) DBG('msg: ' + msg.action);
    if (msg.action === 'pupSync') {
        /* tell Lua exactly which focus panels are actually on screen */
        const visible = [];
        FOCUS_PANEL_IDS.forEach((id) => {
            const el = document.getElementById(id);
            if (el && !el.classList.contains('hidden')) visible.push(id);
        });
        NUI('pupSyncState', { visible });
        return;
    }
    if (msg.action === 'hideAll') {
        /* panic button (/hideui): close every overlay, reset transient state */
        ['wheel-wrap', 'radial-wrap', 'ink-wrap', 'death-wrap', 'shop-wrap', 'ward-wrap',
         'list-wrap', 'deck-wrap', 'pm-wrap', 'poster-wrap', 'input-wrap',
         'app-wrap'].forEach((id) => {
            const el = document.getElementById(id);
            if (el) el.classList.add('hidden');
        });
        radialStack = [];
        inkData = null;
        appState = null;
        return;
    }
    if (msg.action === 'panelsHide') {
        /* focus-holding panels only (death/poster/ink stay): used when a
           panel must be force-closed, e.g. the player died with a menu up */
        ['wheel-wrap', 'radial-wrap', 'shop-wrap', 'ward-wrap',
         'list-wrap', 'deck-wrap', 'pm-wrap', 'input-wrap',
         'app-wrap'].forEach((id) => {
            const el = document.getElementById(id);
            if (el) el.classList.add('hidden');
        });
        radialStack = [];
        appState = null;
        return;
    }
    if (msg.action === 'world3d') { world3dRender(msg.data || {}); return; }
    if (msg.action === 'world3dHide') { world3dHide(); return; }
    if (msg.action === 'sceneLabels') { sceneLabelsRender(msg.data || {}); return; }
    if (msg.action === 'sceneLabelsHide') { sceneLabelsHide(); return; }
    if (msg.action === 'app') { openApp(msg.data || {}); return; }
    if (msg.action === 'appUpdate') { updateApp(msg.data || {}); return; }
    if (msg.action === 'appHide') { hideApp(); return; }
    if (msg.action === 'pmHide') { pmWrap.classList.add('hidden'); return; }
    if (msg.action === 'deckHide') { deckWrap.classList.add('hidden'); return; }
    if (msg.action === 'inkInput') { openInkInput(msg.data || {}); return; }
    if (msg.action === 'inputHide') { inputWrap.classList.add('hidden'); return; }
    if (msg.action === 'hud') { renderHud(msg.data || {}); return; }
    if (msg.action === 'menuSide') {
        document.body.classList.toggle('menu-right', (msg.data || {}).side === 'right');
        return;
    }
    if (msg.action === 'death') { showDeath(msg.data || {}); return; }
    if (msg.action === 'deathUpdate') { updateDeath(msg.data || {}); return; }
    if (msg.action === 'deathHide') { hideDeath(); return; }
    if (msg.action === 'honor') { showHonor(msg.data || {}); return; }
    if (msg.action === 'playerMenu') { openPlayerMenu(msg.data || {}); return; }
    if (msg.action === 'perkDeck') { openDeck(msg.data || {}); return; }
    if (msg.action === 'prompt') { showPrompt(msg.data || {}); return; }
    if (msg.action === 'worldKey') { showWorldKey(msg.data || {}); return; }
    if (msg.action === 'worldKeyHide') { hideWorldKey(); return; }
    if (msg.action === 'doorSound') { playDoorSound((msg.data || {}).kind); return; }
    if (msg.action === 'shop') { openShop(msg.data || {}); return; }
    if (msg.action === 'shopHide') { shopWrap.classList.add('hidden'); return; }
    if (msg.action === 'wardrobe') { openWardrobe(msg.data || {}); return; }
    if (msg.action === 'wardrobeUpdate') { wardUpdate(msg.data || {}); return; }
    if (msg.action === 'wardrobeHide') { if (wardWrap) wardWrap.classList.add('hidden'); return; }
    if (msg.action === 'promptHide') { promptWrap.classList.add('hidden'); return; }
    if (msg.action === 'progress') { startProgress(msg.data || {}); return; }
    if (msg.action === 'progressHide') { hideProgress(); return; }
    if (msg.action === 'progressPos') { progressPos(msg.data || {}); return; }
    if (msg.action === 'progressStyle') { setProgressStyle(msg.data || {}); return; }
    if (msg.action === 'listMenu') { openListMenu(msg.data || {}); return; }
    if (msg.action === 'listMenuState') { listSetSel((msg.data || {}).index || 1); return; }
    if (msg.action === 'listMenuHide') { closeListMenu(false); return; }
    if (msg.action === 'inkMenu') {
        inkData = msg.data || { options: [], index: 1 };
        renderInkMenu();
        // opt-in skin: drop any previous theme-* then apply this menu's, so a
        // themed menu can never leave its look behind on the next one
        Array.from(inkWrap.classList).forEach((c) => { if (c.startsWith('theme-')) inkWrap.classList.remove(c); });
        if (inkData.theme) inkWrap.classList.add('theme-' + String(inkData.theme).replace(/[^a-z0-9_-]/gi, ''));
        // per-menu side, independent of the player's body.menu-right preference
        inkWrap.classList.toggle('side-right', inkData.side === 'right');
        inkWrap.classList.remove('hidden');
        return;
    }
    if (msg.action === 'pricePicker') { pricePickerOpen(msg.data || {}); return; }
    if (msg.action === 'pricePickerState') { pricePickerState(msg.data || {}); return; }
    if (msg.action === 'pricePickerHide') { document.getElementById('price-wrap').classList.add('hidden'); priceData = null; return; }
    if (msg.action === 'inkMenuState') { inkMenuState(msg.data || {}); return; }
    if (msg.action === 'inkMenuHide') { inkWrap.classList.add('hidden'); inkData = null; updateInkImage(); return; }
    if (msg.action === 'perkDeckUpdate') {
        if (!deckWrap.classList.contains('hidden')) renderDeck(msg.data || {});
        return;
    }
    if (msg.action === 'banner') {
        bannerQueue.push(msg.data || {});
        nextBanner();
    } else if (msg.action === 'toast') {
        addToast(msg.data || {});
    } else if (msg.action === 'poster') {
        showPoster(msg.data || {});
    } else if (msg.action === 'wheel') {
        openWheel(msg.data || {});
    } else if (msg.action === 'wheelHide') {
        wheelWrap.classList.add('hidden');
    } else if (msg.action === 'radial') {
        openRadial(msg.data || {});
    } else if (msg.action === 'radialHide') {
        radialWrap.classList.add('hidden');
        radialStack = [];
    }
});


// some descriptions arrive with literal <br>; everything renders through
// textContent, so turn them into newlines (desc styles use pre-line)
function stripBr(s) {
    return String(s == null ? '' : s).replace(/<br\s*\/?>/gi, '\n');
}