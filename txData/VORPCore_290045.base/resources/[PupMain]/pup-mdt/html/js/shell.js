'use strict';
// The clipboard shell: theme, letterhead, Index drawer, edge tabs, Back bookmark,
// preferences, fade, tab switching and the open/close life cycle.

App.order = ['dashboard', 'firmhome', 'bounties', 'mostwanted', 'citizens', 'reports', 'citations', 'statements',
    'evidence', 'cases', 'roster', 'prisons', 'alerts', 'tips', 'expungements', 'bail', 'appeals', 'defense',
    'barroster', 'firmledger', 'firmsettings', 'permissions', 'audit', 'settings'];

// regTab({ id, label(), icon, perm, feature, build(root), show(opts), reset(), canLeave() })
function regTab(def) { App.tabs[def.id] = def; }

const EdgeTabs = [
    { id: 'bounties', key: 'ui_edge_warrants', def: 'Warrants', tone: 'red' },
    { id: 'reports', key: 'ui_edge_reports', def: 'Reports', tone: 'paper' },
    { id: 'citations', key: 'ui_edge_citations', def: 'Citations', tone: 'rust' },
    { id: 'statements', key: 'ui_edge_witness', def: 'Witness', tone: 'green' },
    { id: 'evidence', key: 'ui_edge_evidence', def: 'Evidence', tone: 'leather' },
];

function tabVisible(id) {
    const t = App.tabs[id];
    if (!t || !App.player) return false;
    return can(t.perm) && featureOn(t.feature);
}

// ---------- theme ----------
const ColorVars = ['paper', 'raised', 'header', 'deep', 'ink', 'woodDark', 'wood', 'leather', 'accent', 'gold', 'red', 'green',
    'brown', 'brownDark', 'brownDeep', 'well', 'leatherLight', 'cream', 'heading', 'paperHi', 'pressed', 'card', 'btn', 'btnHover',
    'dangerHover', 'blue', 'purple', 'orange', 'grey', 'teal'];
function cssName(k) { return '--' + k.replace(/[A-Z]/g, (m) => '-' + m.toLowerCase()); }
function safeColor(v) { return typeof v === 'string' && /^(#[0-9a-f]{3,8}|rgba?\([\d\s.,%]+\))$/i.test(v.trim()) ? v.trim() : null; }
function safeFont(v) { return typeof v === 'string' && /^[A-Za-z0-9 ,'"-]+$/.test(v) ? v : null; }
function applyTheme(theme, root) {
    theme = theme || {};
    const r = root || document.documentElement;
    const colors = theme.colors || {};
    for (const k of ColorVars) { const c = safeColor(colors[k]); if (c) r.style.setProperty(cssName(k), c); }
    const fonts = theme.fonts || {};
    for (const k of ['body', 'heading', 'type', 'wood', 'hand']) { const f = safeFont(fonts[k]); if (f) r.style.setProperty('--font-' + k, f); }
    if (theme.fontImport && /^https:\/\/fonts\.googleapis\.com\//.test(theme.fontImport) && !document.querySelector('link[data-theme-font]')) {
        document.head.appendChild(h('link', { rel: 'stylesheet', href: theme.fontImport, 'data-theme-font': '1' }));
    }
    const tint = str(theme.stampTint, 'original');
    const filters = { original: 'none', ink: 'grayscale(1) brightness(0.4)', pink: 'sepia(1) hue-rotate(300deg) saturate(2)', sepia: 'sepia(1)' };
    const f = filters[tint] !== undefined ? filters[tint] : (/^[a-z0-9().,%\s-]+$/i.test(tint) ? tint : 'none');
    r.style.setProperty('--stamp-filter', f);
}

// ---------- letterhead and footer ----------
function letterLines() {
    const th = App.cfg.theme || {};
    const lh = th.letterhead || {};
    if (App.lawyer) {
        const firm = str(App.firmName) || str(lh.line1, T('ui_lh_line1', 'Dusk County Law'));
        return [firm, str(th.lawyerSubtitle || lh.lawyerLine2, T('ui_lh_lawyer_line2', 'Law Office')), str(th.lawyerTagline || lh.lawyerLine3, T('ui_lh_lawyer_line3', 'Attorneys at Law'))];
    }
    return [str(lh.line1, T('ui_lh_line1', 'Dusk County Law')), str(lh.line2, T('ui_lh_line2', "Sheriff's Office")), str(lh.line3, T('ui_lh_line3', 'Criminal Registry'))];
}
function drawLetterhead() {
    const [l1, l2, l3] = letterLines();
    fill($('#letterhead'),
        h('img', { class: 'lh-seal', src: 'img/stamp.svg', alt: '' }),
        h('div', { class: 'lh-text' },
            h('div', { class: 'lh-1' }, '— ' + l1 + ' —'),
            h('div', { class: 'lh-2' }, l2),
            h('div', { class: 'lh-3' }, l3)),
        h('button', { class: 'ibtn lh-prefs', type: 'button', title: T('ui_preferences', 'Preferences'), onclick: openPrefs }, icon('tune')));
}
function rankText() {
    const p = App.player || {};
    return str(p.rank || p.rankLabel || p.gradeLabel || p.grade_label || p.jobGradeLabel, T('ui_deputy', 'Deputy'));
}
function drawDrawer() {
    const d = $('#drawer');
    const list = h('ul', { class: 'idx' });
    for (const id of App.order) {
        const t = App.tabs[id];
        if (!t || !tabVisible(id)) continue;
        const li = h('li', { class: 'idx-row' + (App.current === id ? ' on' : ''), onclick: () => { App.showTab(id); toggleDrawer(false); } },
            icon(t.icon), h('span', { class: 'idx-l' }, t.label()), h('span', { class: 'idx-dots' }));
        if (id === 'tips') {
            const n = App.unreadTips || 0;
            li.appendChild(h('span', { class: 'idx-badge' + (n > 0 ? '' : ' hidden') }, n > 99 ? '99+' : String(n)));
        }
        list.appendChild(li);
    }
    const p = App.player || {};
    fill(d,
        h('div', { class: 'idx-head' }, T('ui_index', '— INDEX —')),
        list,
        h('div', { class: 'idx-foot' },
            h('small', null, App.lawyer ? str(p.footerLabel, T('ui_attorney', 'Attorney')) : T('ui_lawman', 'Lawman')),
            h('b', null, str(p.name, '')),
            h('span', null, rankText(), p.isBoss ? h('span', { class: 'crown', title: T('ui_boss', 'Boss') }, icon('workspace_premium')) : null)),
        h('button', { class: 'btn danger sm idx-close', type: 'button', onclick: () => App.close(true) }, icon('close'), T('ui_close_mdt', 'Close MDT')));
}
function toggleDrawer(on) {
    const d = $('#drawer');
    const open = on === undefined ? !d.classList.contains('open') : on;
    d.classList.toggle('open', open);
    if (open) pushLayer(d, () => toggleDrawer(false)); else popLayer(d);
}
function drawEdgeTabs() {
    const nav = $('#edgeTabs');
    clear(nav);
    for (const e of EdgeTabs) {
        if (!tabVisible(e.id)) continue;
        nav.appendChild(h('button', { class: 'etab tone-' + e.tone + (App.current === e.id ? ' on' : ''), type: 'button', onclick: () => App.showTab(e.id) },
            h('span', null, T(e.key, e.def))));
    }
    nav.appendChild(h('button', { class: 'etab tone-close', type: 'button', onclick: () => App.close(true) }, h('span', null, T('ui_close', 'Close'))));
}
App.redrawNav = () => { drawDrawer(); drawEdgeTabs(); };
App.setUnreadTips = (n) => { App.unreadTips = Math.max(0, num(n)); drawDrawer(); };

// ---------- tabs ----------
App.showTab = async (id, opts, fromBack) => {
    if (!tabVisible(id)) { if (id) notify(T('ui_no_access', 'You do not have access to that page')); return; }
    const cur = App.current && App.tabs[App.current];
    if (cur && App.current !== id && cur.canLeave && !(await cur.canLeave())) return;
    if (App.current && App.current !== id && !fromBack) App.history.push(App.current);
    if (App.history.length > 30) App.history.shift();
    const content = $('#content');
    for (const s of content.children) s.classList.add('hidden');
    let root = App.built[id];
    const t = App.tabs[id];
    if (!root) {
        root = h('section', { class: 'tab tab-' + id });
        content.appendChild(root);
        App.built[id] = root;
        t.build(root);
    }
    root.classList.remove('hidden');
    root.classList.remove('page-turn'); void root.offsetWidth; root.classList.add('page-turn');
    App.current = id;
    App.redrawNav();
    if (t.show) t.show(opts || {});
};
App.back = () => {
    while (App.history.length) {
        const id = App.history.pop();
        if (tabVisible(id)) { App.showTab(id, null, true); return; }
    }
};
// Re-checks visibility after permissions or switches change.
App.recheckTabs = () => {
    for (const id in App.built) {
        if (!tabVisible(id)) {
            App.built[id].remove();
            delete App.built[id];
            if (App.tabs[id].reset) App.tabs[id].reset();
            if (App.current === id) App.current = null;
        }
    }
    if (!App.current || !tabVisible(App.current)) {
        const first = tabVisible('dashboard') ? 'dashboard' : App.order.find(tabVisible);
        if (first) App.showTab(first); else fill($('#content'), emptyState(T('ui_no_pages', 'No pages available'), null, 'lock'));
    }
    App.redrawNav();
};

// ---------- preferences ----------
function prefScale() { try { return localStorage.getItem('pupmdt_textsize') || 'normal'; } catch (e) { return 'normal'; } }
function applyScale(v) {
    const map = { small: 0.85, normal: 1, large: 1.18 };
    document.documentElement.style.setProperty('--text-scale', String(map[v] || 1));
}
function openPrefs() {
    const cur = prefScale();
    const opts = [['small', T('ui_text_small', 'Small')], ['normal', T('ui_text_normal', 'Normal')], ['large', T('ui_text_large', 'Large')]];
    const group = h('div', { class: 'seg' }, opts.map(([v, l]) => h('button', {
        class: 'btn sm' + (v === cur ? ' primary' : ' ghost'), type: 'button',
        onclick: () => { try { localStorage.setItem('pupmdt_textsize', v); } catch (e) { /* storage off */ } applyScale(v); m.close(); openPrefs(); },
    }, l)));
    const m = modal({ title: T('ui_preferences', 'Preferences'), icon: 'tune', body: [field(T('ui_text_size', 'Text size'), group), h('p', { class: 'muted' }, T('ui_saved_on_device', 'Saved on this device'))], backdropCloses: true });
}

// ---------- fade ----------
let fadeBlockUntil = 0;
function setupFade() {
    const b = $('#board');
    // never fade while a pop-up is open: pop-ups live outside the board, so reaching one leaves it
    const pops = $('#overlays');
    b.addEventListener('mouseleave', () => {
        if (pops.children.length === 0 && Date.now() > fadeBlockUntil && App.open) b.classList.add('faded');
    });
    new MutationObserver(() => { if (pops.children.length > 0) b.classList.remove('faded'); }).observe(pops, { childList: true });
    b.addEventListener('mouseenter', () => b.classList.remove('faded'));
}

// ---------- open / close ----------
App.openMDT = (data) => {
    data = data || {};
    App.cfg = data.config || {};
    App.lawyer = !!(data.isLawyer || (data.playerData && data.playerData.isLawyer));
    if (data.playerData) App.setPlayer(data.playerData, true);
    applyTheme(App.cfg.theme);
    const board = $('#board');
    board.classList.toggle('lawyer', App.lawyer);
    board.classList.toggle('landscape', str((App.cfg.theme || {}).layout) === 'landscape');
    const tint = safeColor(App.cfg.boardColor);
    if (tint && (App.cfg.theme || {}).regionColors !== false) board.style.setProperty('--board-tint', tint); else board.style.removeProperty('--board-tint');
    const logo = str((App.cfg.theme || {}).logo, 'img/logo.png');
    $('#cornerStamp').src = /^(img\/|nui:\/\/|https:\/\/)/.test(logo) ? logo : 'img/logo.png';
    const pos = str((App.cfg.theme || {}).toastPosition, 'bottom-center');
    $('#slips').className = 'slips pos-' + (['bottom-center', 'top-center', 'top-right'].includes(pos) ? pos : 'bottom-center');
    applyScale(prefScale());
    drawLetterhead();
    $('#bmIndex').textContent = T('ui_bm_index', 'Index');
    $('#bmBack').textContent = T('ui_bm_back', 'Back');
    App.open = true;
    fadeBlockUntil = Date.now() + 300;
    board.classList.remove('faded');
    show($('#mdt'), true);
    App.history = [];
    App.current = null;
    App.recheckTabs();
    if (tabVisible('tips')) App.tabs.tips.preload && App.tabs.tips.preload();
};
App.setPlayer = (pd, quiet) => {
    if (!pd || typeof pd !== 'object') return;
    App.player = pd;
    if (pd.settings && typeof pd.settings === 'object') App.settings = pd.settings;
    if (pd.mdtSettings && typeof pd.mdtSettings === 'object') App.settings = pd.mdtSettings;
    if (pd.firmName !== undefined) App.firmName = pd.firmName;
    if (pd.isLawyer !== undefined) App.lawyer = !!pd.isLawyer;
    if (!quiet && App.open) { drawLetterhead(); App.recheckTabs(); }
};
// close(fromPage): fromPage=true tells the client; false when the client already closed it.
App.close = (fromPage) => {
    if (!App.open) return;
    App.open = false;
    stopTimers();
    closeAllLayers();
    clear($('#overlays'));
    toggleDrawer(false);
    for (const id in App.tabs) { try { if (App.tabs[id].reset) App.tabs[id].reset(); } catch (e) { /* keep closing */ } }
    clear($('#content'));
    App.built = {};
    App.current = null;
    App.history = [];
    show($('#mdt'), false);
    if (fromPage) nui('closeMDT', {});
};
App.handleEsc = () => {
    if (closeTopLayer()) { App.escConsumedAt = Date.now(); return; }
    App.escConsumedAt = Date.now();
    if (App.open) App.close(false);
    // always tell the client, so a page that failed to open can never keep the cursor
    nui('closeFromEsc', {});
};

// ---------- slips (toasts) ----------
function slip(message, duration) {
    const ms = Math.max(1800, num(duration, 4000));
    const bar = h('div', { class: 'slip-ink' });
    const el = h('div', { class: 'slip', style: { transform: 'rotate(' + ((Math.random() * 2.4) - 1.2).toFixed(2) + 'deg)' } },
        h('span', { class: 'slip-star' }, icon('star')),
        h('div', { class: 'slip-body' }, h('div', { class: 'slip-title' }, T('ui_slip_title', 'MDT')), h('div', { class: 'slip-msg' }, str(message))),
        bar);
    bar.style.animationDuration = ms + 'ms';
    $('#slips').appendChild(el);
    setTimeout(() => el.classList.add('out'), ms - 320);
    setTimeout(() => el.remove(), ms);
}
App.slip = slip;

document.addEventListener('DOMContentLoaded', () => {
    $('#bmIndex').addEventListener('click', () => toggleDrawer());
    $('#bmBack').addEventListener('click', () => App.back());
    $('#page').addEventListener('mousedown', () => { if ($('#drawer').classList.contains('open')) toggleDrawer(false); });
    setupFade();
    applyScale(prefScale());
});
