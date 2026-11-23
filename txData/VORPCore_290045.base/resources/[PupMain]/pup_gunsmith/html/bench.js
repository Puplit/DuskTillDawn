/* pup_gunsmith | bench page
   Everything shown here is text set with textContent; the only markup built in code is
   fixed SVG for the arrows. Prices on this page are for display: the server prices and
   checks every fit, preset and repair itself. */
'use strict';

const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pup_gunsmith';

function post(name, data) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({ ok: false }));
}

const $ = (id) => document.getElementById(id);

function el(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined && text !== null) e.textContent = String(text);
    return e;
}

const ARROW_L = '<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M7 1 L2 5 L7 9 Z"/></svg>';
const ARROW_R = '<svg viewBox="0 0 10 10" aria-hidden="true"><path d="M3 1 L8 5 L3 9 Z"/></svg>';

const FIXED_ORDER = ['BARREL', 'GRIP', 'SIGHT', 'SCOPE', 'CLIP', 'MAG', 'TUBE', 'STOCK', 'WRAP', 'STRAP',
    'BARREL_RIFLING', 'TORCH_MATCHSTICK', 'FRAME_VERTDATA'];
const TAB_IDS = ['parts', 'finish', 'engraving', 'tints', 'presets', 'workshop'];
const AXIS_KEYS = { KeyA: ['turn', -1], KeyD: ['turn', 1], KeyW: ['tilt', 1], KeyS: ['tilt', -1], KeyQ: ['roll', -1], KeyE: ['roll', 1] };

/* ---------------------------------------------------------------------- state */
let T = {};                                  // wording from the locale
let NAMES = { weapons: {}, categories: {} }; // display names
let CFG = {};

const S = {
    open: false,
    view: 'pick',        // 'pick' | 'sheet'
    bench: '',
    guns: [],
    wallet: { cash: 0, gold: 0 },
    wear: false,
    pickFocus: 0,
    gun: null,           // { id, name, label, serial }
    catalogue: {},
    fitted: {},
    sel: {},
    card: null,
    presets: [],
    tab: 'parts',
    focus: 0,
    working: false,
    picking: false,
    receipt: false,
    naming: false,
    armed: null,         // { id, timer }
};

/* ---------------------------------------------------------------------- formatting */
function fmt(s, ...args) {
    let i = 0;
    return String(s || '').replace(/%[sd]/g, () => (i < args.length ? String(args[i++]) : ''));
}

function dollars(n) {
    let s = (Number(n) || 0).toFixed(2);
    if (s.endsWith('.00')) s = s.slice(0, -3);
    return '$' + s;
}

function money(cash, gold) {
    const parts = [];
    cash = Math.max(0, Math.floor(Number(cash) || 0));
    gold = Math.max(0, Math.floor(Number(gold) || 0));
    if (cash > 0) parts.push(dollars(cash));
    if (gold > 0) parts.push(gold + ' G');
    return parts.length ? parts.join(' · ') : (T.free || 'Free');
}

function walletText() {
    let s = '$' + (Number(S.wallet.cash) || 0).toFixed(2);
    const g = Number(S.wallet.gold) || 0;
    if (g > 0) s += ' · ' + Math.floor(g) + ' G';
    return fmt(T.wallet, s);
}

function titleCase(name) {
    return String(name).toLowerCase().split('_').filter(Boolean)
        .map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
}

function catLabel(cat) { return NAMES.categories[cat] || titleCase(cat); }

function variantName(v) {
    if (v.label) return v.label;
    const words = String(v.item).split('_').filter(Boolean);
    return titleCase(words.slice(-2).join('_'));
}

function tabOf(cat) {
    if (cat.endsWith('_TINT')) return 'tints';
    if (cat.includes('ENGRAVING')) return 'engraving';
    if (cat.endsWith('_MATERIAL')) return 'finish';
    return 'parts';
}

function count(o) { return o ? Object.keys(o).length : 0; }
function copy(o) { return Object.assign({}, o || {}); }
function same(a, b) {
    a = a || {}; b = b || {};
    const ka = Object.keys(a), kb = Object.keys(b);
    if (ka.length !== kb.length) return false;
    return ka.every((k) => a[k] === b[k]);
}
function selOf(cat) { return S.sel[cat] || null; }
function fitOf(cat) { return S.fitted[cat] || null; }

/* ---------------------------------------------------------------------- theme */
function applyTheme(theme) {
    if (!theme || typeof theme !== 'object') return;
    const fontOk = (f) => typeof f === 'string' && /^[\w.-]+\.(ttf|otf)$/i.test(f);
    const fonts = theme.fonts || {};
    let css = '';
    if (fontOk(fonts.title)) css += `@font-face{font-family:'GsTitle';src:url('nui://pup-ui/html/fonts/${fonts.title}');}`;
    if (fontOk(fonts.body)) css += `@font-face{font-family:'GsBody';src:url('nui://pup-ui/html/fonts/${fonts.body}');}`;
    let tag = document.getElementById('gs-fonts');
    if (!tag) { tag = document.createElement('style'); tag.id = 'gs-fonts'; document.head.appendChild(tag); }
    tag.textContent = css;
    const colours = theme.colors || {};
    const okColour = (c) => typeof c === 'string' && /^(#[0-9a-f]{3,8}|rgba?\([\d\s.,]+\))$/i.test(c);
    const map = { text: '--text', textDim: '--dim', accent: '--gold', danger: '--red', good: '--ok', border: '--line' };
    Object.keys(map).forEach((k) => { if (okColour(colours[k])) document.documentElement.style.setProperty(map[k], colours[k]); });
}

/* ---------------------------------------------------------------------- toast and progress */
let toastTimer = null;
function toast(text, tone) {
    if (!text) return;
    const t = $('toast');
    t.textContent = text;
    t.className = 'toast' + (tone ? ' ' + tone : '');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.add('hidden'), 3800);
}

function progress(label, ms) {
    return new Promise((resolve) => {
        const box = $('progress');
        const fill = $('progressFill');
        $('progressLabel').textContent = label || '';
        fill.style.transition = 'none';
        fill.style.width = '0%';
        box.classList.remove('hidden');
        void fill.offsetWidth; // restart the transition
        fill.style.transition = `width ${Math.max(0, ms)}ms linear`;
        fill.style.width = '100%';
        setTimeout(() => { box.classList.add('hidden'); resolve(); }, Math.max(0, ms));
    });
}

/* ---------------------------------------------------------------------- the pick screen */
function gunLabel(g) { return g.label || NAMES.weapons[String(g.name).toUpperCase()] || g.name; }

function renderPick() {
    $('pick').classList.remove('hidden');
    $('sheet').classList.add('hidden');
    $('pickBench').textContent = S.bench;
    $('pickTitle').textContent = T.pickTitle;
    $('pickSub').textContent = T.pickSub;
    $('pickFoot').textContent = T.pickFooter;
    const list = $('pickList');
    list.textContent = '';
    if (!S.guns.length) {
        list.appendChild(el('div', 'empty', T.pickEmpty));
        return;
    }
    if (S.pickFocus >= S.guns.length) S.pickFocus = 0;
    S.guns.forEach((g, i) => {
        const card = el('div', 'gun' + (i === S.pickFocus ? ' focus' : ''));
        const main = el('div', 'main');
        main.appendChild(el('div', 'name', gunLabel(g)));
        const bits = [];
        if (g.serial) bits.push(fmt(T.serialShort, g.serial));
        bits.push(g.parts > 0 ? fmt(T.partsFitted, g.parts) : T.factoryFit);
        main.appendChild(el('div', 'meta', bits.join(' · ')));
        card.appendChild(main);
        card.appendChild(el('div', 'go', T.pickAction));
        card.addEventListener('mouseenter', () => {
            if (S.pickFocus !== i) { S.pickFocus = i; renderPick(); }
        });
        card.addEventListener('click', () => pick(i));
        list.appendChild(card);
    });
}

async function pick(i) {
    const g = S.guns[i];
    if (!g || S.picking || S.working) return;
    S.picking = true;
    const res = await post('pick', { id: g.id });
    S.picking = false;
    if (!S.open) return;
    if (!res || !res.ok) {
        toast((res && res.msg) || T.spawnFailed, 'bad');
        return;
    }
    S.gun = { id: g.id, name: g.name, label: gunLabel(g), serial: g.serial };
    S.catalogue = res.catalogue || {};
    S.fitted = copy(res.fitted);
    S.sel = copy(res.fitted);
    S.card = res.card || null;
    if (res.wallet) S.wallet = res.wallet;
    S.presets = Array.isArray(res.presets) ? res.presets : [];
    S.view = 'sheet';
    S.tab = visibleTabs()[0];
    S.focus = 0;
    S.receipt = false;
    S.naming = false;
    $('root').classList.add('ongun');
    renderKeys(true);
    renderSheet();
}

/* ---------------------------------------------------------------------- the sheet */
function visibleTabs() {
    const have = {};
    Object.keys(S.catalogue).forEach((c) => { have[tabOf(c)] = true; });
    return TAB_IDS.filter((t) => t === 'presets' || t === 'workshop' || have[t]);
}

function catsOf(tab) {
    const cats = Object.keys(S.catalogue).filter((c) => tabOf(c) === tab && (S.catalogue[c] || []).length);
    cats.sort((a, b) => {
        const ia = FIXED_ORDER.indexOf(a), ib = FIXED_ORDER.indexOf(b);
        if (ia !== -1 || ib !== -1) {
            if (ia !== -1 && ib !== -1) return ia - ib;
            return ia !== -1 ? -1 : 1;
        }
        return catLabel(a).localeCompare(catLabel(b));
    });
    return cats;
}

function choices(cat) {
    const list = (S.catalogue[cat] || []).map((v) => ({
        item: v.item, label: variantName(v), cash: Number(v.cash) || 0, gold: Number(v.gold) || 0,
    }));
    const out = [];
    if (cat !== 'GRIP') out.push({ item: null, label: T.none, none: true });
    list.forEach((v) => out.push(v));
    const f = fitOf(cat);
    if (f && !list.some((v) => v.item === f)) out.push({ item: f, label: T.currentPart, cash: 0, gold: 0, current: true });
    return out;
}

function priceOf(cat, item) {
    if (!item || item === fitOf(cat)) return { cash: 0, gold: 0 };
    const v = (S.catalogue[cat] || []).find((x) => x.item === item);
    if (!v) return { cash: 0, gold: 0 };
    return { cash: Math.max(0, Math.floor(Number(v.cash) || 0)), gold: Math.max(0, Math.floor(Number(v.gold) || 0)) };
}

function changedCats(a, b) {
    const keys = new Set(Object.keys(a || {}).concat(Object.keys(b || {})));
    return [...keys].filter((k) => ((a || {})[k] || null) !== ((b || {})[k] || null));
}

function bill() {
    let cash = 0, gold = 0;
    const changes = changedCats(S.sel, S.fitted);
    changes.forEach((cat) => {
        const p = priceOf(cat, selOf(cat));
        cash += p.cash; gold += p.gold;
    });
    return { changes, cash, gold };
}

function renderSheet() {
    // a late answer (card, preset timer) can arrive after the gun was put away
    if (!S.open || !S.gun || S.view !== 'sheet') return;
    $('pick').classList.add('hidden');
    $('sheet').classList.remove('hidden');
    $('sheetKicker').textContent = fmt(T.sheetKicker, S.bench);
    $('sheetTitle').textContent = S.gun.label;
    $('sheetSerial').textContent = S.gun.serial ? fmt(T.serialLong, S.gun.serial) : '';

    const tabs = $('tabs');
    tabs.textContent = '';
    visibleTabs().forEach((t) => {
        const e = el('div', 'tab' + (t === S.tab ? ' active' : ''), (T.tabs || {})[t] || t);
        e.addEventListener('click', () => setTab(t));
        tabs.appendChild(e);
    });

    const rows = $('rows');
    const keep = rows.scrollTop;
    rows.textContent = '';
    if (S.tab === 'presets') renderPresets(rows);
    else if (S.tab === 'workshop') renderWorkshop(rows);
    else renderParts(rows);
    rows.scrollTop = keep;
    const f = rows.querySelector('.focus');
    if (f && f.scrollIntoView) f.scrollIntoView({ block: 'nearest' });

    renderBill();
}

function renderParts(host) {
    const cats = catsOf(S.tab);
    if (!cats.length) { host.appendChild(el('div', 'empty', T.nothingHere)); return; }
    if (S.focus >= cats.length) S.focus = 0;
    cats.forEach((cat, i) => {
        const opts = choices(cat);
        const sel = selOf(cat);
        const fit = fitOf(cat);
        let idx = opts.findIndex((o) => o.item === sel);
        if (idx < 0) idx = 0;
        const cur = opts[idx];
        const row = el('div', 'row' + (i === S.focus ? ' focus' : '') + (sel !== fit ? ' changed' : ''));

        const head = el('div', 'r-head');
        head.appendChild(el('span', null, catLabel(cat)));
        head.appendChild(el('span', 'now', cur ? cur.label : ''));
        row.appendChild(head);

        const selector = el('div', 'selector');
        const left = el('span', 'arrow'); left.innerHTML = ARROW_L;
        const right = el('span', 'arrow'); right.innerHTML = ARROW_R;
        left.addEventListener('click', (e) => { e.stopPropagation(); S.focus = i; change(-1); });
        right.addEventListener('click', (e) => { e.stopPropagation(); S.focus = i; change(1); });
        selector.appendChild(left);
        selector.appendChild(el('span', 'cur', cur ? cur.label : ''));
        selector.appendChild(right);
        row.appendChild(selector);

        const meta = el('div', 'r-meta');
        const partCount = opts.filter((o) => !o.none).length;
        if (cur && cur.item === fit) {
            meta.appendChild(el('span', 'gold', T.fittedNow));
        } else if (!cur || cur.none) {
            meta.appendChild(el('span', null, T.removeTag));
        } else {
            const p = priceOf(cat, cur.item);
            meta.appendChild(el('span', null, money(p.cash, p.gold)));
        }
        if (!cur || cur.none) {
            meta.appendChild(el('span', null, fmt(T.toChoose, partCount)));
        } else {
            const n = opts.filter((o) => !o.none).findIndex((o) => o.item === cur.item) + 1;
            meta.appendChild(el('span', null, fmt(T.ofCount, n, partCount)));
        }
        row.appendChild(meta);

        if (opts.length <= 24) {
            const dots = el('div', 'dots');
            opts.forEach((o, j) => {
                dots.appendChild(el('span', 'dot' + (o.item === fit && !o.none ? ' fitted' : '') + (j === idx ? ' sel' : '')));
            });
            row.appendChild(dots);
        }

        row.addEventListener('click', () => { if (S.focus !== i) { S.focus = i; renderSheet(); } });
        host.appendChild(row);
    });
}

function renderBill() {
    const b = bill();
    const n = b.changes.length;
    $('billCount').textContent = n ? fmt(T.changes, n) : T.noChanges;
    $('billTotal').textContent = money(b.cash, b.gold);
    $('billWallet').textContent = walletText();
    const undo = $('btnUndo');
    const fit = $('btnFit');
    undo.textContent = T.undoAll;
    fit.textContent = (b.cash > 0 || b.gold > 0) ? T.payAndFit : T.fitParts;
    undo.disabled = !n || S.working;
    fit.disabled = !n || S.working;
}

/* ---------------------------------------------------------------------- changing parts */
function focusedCat() {
    if (S.tab === 'presets' || S.tab === 'workshop') return null;
    return catsOf(S.tab)[S.focus] || null;
}

function change(dir) {
    if (S.working) return;
    const cat = focusedCat();
    if (!cat) return;
    const opts = choices(cat);
    if (!opts.length) return;
    let idx = opts.findIndex((o) => o.item === selOf(cat));
    if (idx < 0) idx = 0;
    idx = (idx + dir + opts.length) % opts.length;
    const next = opts[idx].item;
    if (next === null && cat === 'GRIP') return;
    if (next) S.sel[cat] = next; else delete S.sel[cat];
    post('preview', { cat, comp: next });
    renderSheet();
}

function undoAll() {
    if (S.working) return;
    const changed = changedCats(S.sel, S.fitted);
    if (!changed.length) return;
    S.sel = copy(S.fitted);
    post('refit', { set: S.sel, changed });
    renderSheet();
}

/* ---------------------------------------------------------------------- paying */
function openPay() {
    if (S.working) return;
    const b = bill();
    if (!b.changes.length) return;
    if (b.cash <= 0 && b.gold <= 0) { work(); return; }
    S.receipt = true;
    $('rcKicker').textContent = T.receiptKicker;
    $('rcTitle').textContent = S.gun.label;
    const lines = $('rcLines');
    lines.textContent = '';
    b.changes.forEach((cat) => {
        const item = selOf(cat);
        const line = el('div', 'rc-line');
        const left = el('div');
        left.appendChild(el('div', 'c', catLabel(cat)));
        let name = T.removed;
        if (item) {
            const o = choices(cat).find((x) => x.item === item);
            name = o ? o.label : item;
        }
        left.appendChild(el('div', 'p', name));
        line.appendChild(left);
        const p = priceOf(cat, item);
        line.appendChild(el('div', 'v', money(p.cash, p.gold)));
        lines.appendChild(line);
    });
    $('rcTotalLabel').textContent = T.total;
    $('rcTotal').textContent = money(b.cash, b.gold);
    $('rcNo').textContent = T.notYet;
    $('rcYes').textContent = T.payAndFit;
    $('receipt').classList.remove('hidden');
}

function closeReceipt() {
    S.receipt = false;
    $('receipt').classList.add('hidden');
}

async function work() {
    if (S.working) return;
    closeReceipt();
    S.working = true;
    renderBill();
    await post('busy', { on: true });
    await progress(T.working, CFG.workMs || 6000);
    const res = await post('confirm', { set: S.sel });
    S.working = false;
    if (!S.open || !S.gun) return;
    if (res && res.ok) {
        S.fitted = copy(res.set);
        S.sel = copy(res.set);
        if (res.wallet) S.wallet = res.wallet;
        const g = S.guns.find((x) => x.id === S.gun.id);
        if (g) g.parts = count(S.fitted);
        const paid = res.paid || {};
        const any = (Number(paid.cash) || 0) > 0 || (Number(paid.gold) || 0) > 0;
        toast(any ? fmt(T.workDonePaid, money(paid.cash, paid.gold)) : T.workDone, 'good');
    } else {
        toast((res && res.msg) || '', 'bad');
    }
    renderSheet();
}

/* ---------------------------------------------------------------------- presets */
function presetLook(p) {
    const out = {};
    Object.keys(p.parts || {}).forEach((cat) => {
        const comp = p.parts[cat];
        if ((S.catalogue[cat] || []).some((v) => v.item === comp)) out[cat] = comp;
    });
    if (S.fitted.GRIP && !out.GRIP) out.GRIP = S.fitted.GRIP;
    return out;
}

function presetCost(look) {
    let cash = 0, gold = 0;
    Object.keys(look).forEach((cat) => {
        if (look[cat] !== fitOf(cat)) {
            const p = priceOf(cat, look[cat]);
            cash += p.cash; gold += p.gold;
        }
    });
    return { cash, gold };
}

function sortedPresets() {
    return S.presets.slice().sort((a, b) => String(a.name).localeCompare(String(b.name)));
}

function renderPresets(host) {
    const list = sortedPresets();
    const total = 1 + list.length;
    if (S.focus >= total) S.focus = 0;
    const selCount = count(S.sel);

    const save = el('div', 'row' + (S.focus === 0 ? ' focus' : '') + (selCount ? '' : ' disabled'));
    if (S.naming) {
        const box = el('div', 'name-box');
        const lab = el('label', null, T.presetName);
        const input = document.createElement('input');
        input.type = 'text';
        input.maxLength = 32;
        input.placeholder = T.presetHolder || '';
        input.id = 'presetName';
        input.addEventListener('keydown', (e) => {
            e.stopPropagation();
            if (e.key === 'Enter' && !e.repeat) { e.preventDefault(); savePreset(input.value); }
            if (e.key === 'Escape') { e.preventDefault(); stopNaming(); }
        });
        input.addEventListener('keyup', (e) => e.stopPropagation());
        box.appendChild(lab);
        box.appendChild(input);
        box.appendChild(el('div', 'small', T.presetHint));
        save.appendChild(box);
        setTimeout(() => input.focus(), 0);
    } else {
        const line = el('div', 'line-row');
        line.appendChild(el('span', 'lbl', T.presetSaveRow));
        line.appendChild(el('span', 'val dim', fmt(T.presetParts, selCount)));
        save.appendChild(line);
        save.addEventListener('click', () => { S.focus = 0; startNaming(); });
    }
    host.appendChild(save);

    host.appendChild(el('div', 'section', T.presetHeading));
    if (!list.length) {
        host.appendChild(el('div', 'note', T.presetEmpty));
        return;
    }
    list.forEach((p, i) => {
        const look = presetLook(p);
        const onBench = same(look, S.sel);
        const armed = S.armed && S.armed.id === p.id;
        const row = el('div', 'row' + (S.focus === i + 1 ? ' focus' : ''));
        const line = el('div', 'line-row');
        line.appendChild(el('span', 'lbl', p.name));
        const right = el('span');
        right.appendChild(el('span', 'val' + (armed ? ' warn' : ''), armed ? T.presetArmed : (onBench ? T.presetOnBench : T.presetApply)));
        const x = el('span', 'x', '✕');
        x.addEventListener('click', (e) => { e.stopPropagation(); S.focus = i + 1; armDelete(p); });
        right.appendChild(x);
        line.appendChild(right);
        row.appendChild(line);
        const cost = presetCost(look);
        const tail = same(look, S.fitted) ? T.presetFitted : fmt(T.presetCosts, money(cost.cash, cost.gold));
        row.appendChild(el('div', 'small', fmt(T.presetParts, count(look)) + tail));
        row.addEventListener('click', () => { S.focus = i + 1; applyPreset(p); });
        host.appendChild(row);
    });
}

function startNaming() {
    if (S.working || !count(S.sel)) return;
    S.naming = true;
    post('typing', { on: true });
    renderSheet();
}

function stopNaming() {
    if (!S.naming) return;
    S.naming = false;
    post('typing', { on: false });
    renderSheet();
}

async function savePreset(name) {
    const res = await post('presetSave', { name, set: S.sel });
    if (res && res.ok) {
        S.presets = Array.isArray(res.presets) ? res.presets : S.presets;
        toast(fmt(res.replaced ? T.presetUpdated : T.presetSaved, res.name), 'good');
        stopNaming();
    } else {
        toast((res && res.msg) || '', 'bad');
    }
}

function applyPreset(p) {
    if (S.working) return;
    const look = presetLook(p);
    if (same(look, S.sel)) { openPay(); return; }
    const changed = changedCats(S.sel, look);
    S.sel = copy(look);
    post('refit', { set: S.sel, changed });
    toast(T.presetLaid);
    renderSheet();
}

async function armDelete(p) {
    if (S.armed && S.armed.id === p.id) {
        clearTimeout(S.armed.timer);
        S.armed = null;
        const res = await post('presetDelete', { id: p.id });
        if (res && res.ok && Array.isArray(res.presets)) S.presets = res.presets;
        renderSheet();
        return;
    }
    if (S.armed) clearTimeout(S.armed.timer);
    S.armed = { id: p.id, timer: setTimeout(() => { S.armed = null; if (S.open && S.gun) renderSheet(); }, 3000) };
    renderSheet();
}

/* ---------------------------------------------------------------------- workshop */
async function refreshCard() {
    const res = await post('card');
    if (res && res.ok) {
        S.card = res.card || null;
        if (res.wallet) S.wallet = res.wallet;
        if (S.tab === 'workshop') renderSheet();
    }
}

function workshopRows() {
    const c = S.card;
    if (!c || !c.wear || !c.status || !c.status.canDegrade) return [];
    const rows = ['repair'];
    if (c.next) rows.push('temper');
    return rows;
}

function temperShort() {
    const n = S.card && S.card.next;
    if (!n) return true;
    if ((Number(S.wallet.cash) || 0) < (Number(n.cash) || 0)) return true;
    return (n.materials || []).some((m) => (Number(m.have) || 0) < (Number(m.need) || 0));
}

function renderWorkshop(host) {
    const c = S.card;
    if (!c) return;
    if (!c.wear) { host.appendChild(el('div', 'note', T.wearOff)); return; }
    if (!c.status || !c.status.canDegrade) { host.appendChild(el('div', 'note', T.noWear)); return; }
    const rows = workshopRows();
    if (S.focus >= rows.length) S.focus = 0;

    host.appendChild(el('div', 'section', T.condition));
    ['degradation', 'damage', 'dirt', 'soot'].forEach((k) => {
        const v = Math.max(0, Math.min(1, 1 - (Number(c.status[k]) || 0)));
        const pct = Math.round(v * 100);
        const g = el('div', 'gauge' + (pct < 35 ? ' low' : ''));
        const head = el('div', 'g-head');
        head.appendChild(el('span', null, (T.gauges || {})[k] || k));
        head.appendChild(el('span', null, pct + '%'));
        g.appendChild(head);
        const track = el('div', 'g-track');
        const fill = el('div', 'g-fill');
        fill.style.width = pct + '%';
        track.appendChild(fill);
        g.appendChild(track);
        host.appendChild(g);
    });

    const repair = el('div', 'row' + (S.focus === 0 ? ' focus' : ''));
    const rl = el('div', 'line-row');
    rl.appendChild(el('span', 'lbl', T.repairRow));
    rl.appendChild(el('span', 'val', money(c.fee, 0)));
    repair.appendChild(rl);
    repair.addEventListener('click', () => { S.focus = 0; doRepair(); });
    host.appendChild(repair);

    host.appendChild(el('div', 'section', T.tierHeading));
    const pips = el('div', 'pips');
    for (let i = 1; i <= (Number(c.maxTier) || 0); i++) pips.appendChild(el('span', 'pip' + (i <= (Number(c.tier) || 0) ? ' lit' : '')));
    host.appendChild(pips);

    if (c.next) {
        const short = temperShort();
        const t = el('div', 'row' + (S.focus === 1 ? ' focus' : '') + (short ? ' disabled' : ''));
        const tl = el('div', 'line-row');
        tl.appendChild(el('span', 'lbl', fmt(T.temperRow, c.next.tier)));
        tl.appendChild(el('span', 'val', money(c.next.cash, 0)));
        t.appendChild(tl);
        t.appendChild(el('div', 'small', fmt(T.wearsSlower, c.next.slower, c.next.tier)));
        t.addEventListener('click', () => { S.focus = 1; doTier(); });
        host.appendChild(t);
        host.appendChild(el('div', 'section', T.materials));
        (c.next.materials || []).forEach((m) => {
            const ok = (Number(m.have) || 0) >= (Number(m.need) || 0);
            const row = el('div', 'mat ' + (ok ? 'ok' : 'short'));
            row.appendChild(el('span', null, m.label));
            row.appendChild(el('span', 'n', (Number(m.have) || 0) + ' / ' + (Number(m.need) || 0)));
            host.appendChild(row);
        });
    } else {
        host.appendChild(el('div', 'note', T.fullyTempered));
    }
}

async function workshopAction(label, ms, name) {
    if (S.working) return;
    S.working = true;
    renderBill();
    await post('busy', { on: true });
    await progress(label, ms);
    const res = await post(name);
    S.working = false;
    if (!S.open || !S.gun) return;
    if (res) {
        if (res.card) S.card = res.card;
        if (res.wallet) S.wallet = res.wallet;
        if (res.msg) toast(res.msg, res.ok ? 'good' : 'bad');
    }
    renderSheet();
}

function doRepair() { workshopAction(T.repairing, CFG.repairMs || 6000, 'repair'); }
function doTier() { if (!temperShort()) workshopAction(T.upgrading, CFG.tierMs || 8000, 'tier'); }

/* ---------------------------------------------------------------------- tabs and focus */
function setTab(t) {
    if (S.working || S.naming) return;
    if (!visibleTabs().includes(t)) return;
    S.tab = t;
    S.focus = 0;
    renderSheet();
    if (t === 'workshop') refreshCard();
}

function rowCount() {
    if (S.tab === 'presets') return 1 + S.presets.length;
    if (S.tab === 'workshop') return workshopRows().length;
    return catsOf(S.tab).length;
}

function moveFocus(dir) {
    const n = rowCount();
    if (!n) return;
    S.focus = (S.focus + dir + n) % n;
    renderSheet();
}

function activate() {
    if (S.tab === 'presets') {
        if (S.focus === 0) { startNaming(); return; }
        const p = sortedPresets()[S.focus - 1];
        if (p) applyPreset(p);
        return;
    }
    if (S.tab === 'workshop') {
        const r = workshopRows()[S.focus];
        if (r === 'repair') doRepair();
        else if (r === 'temper') doTier();
        return;
    }
    openPay();
}

async function putAway() {
    if (S.working) return;
    const res = await post('putAway');
    if (!res || !res.ok) return;
    S.gun = null;
    S.view = 'pick';
    S.catalogue = {}; S.fitted = {}; S.sel = {}; S.card = null; S.presets = [];
    $('root').classList.remove('ongun');
    renderKeys(false);
    releaseAxes();
    renderPick();
}

function leave() {
    if (S.working) return;
    post('leave');
}

/* ---------------------------------------------------------------------- keys */
function renderKeys(show) {
    const k = $('keys');
    k.textContent = '';
    if (!show) { k.classList.add('hidden'); return; }
    (T.keys || []).forEach((pair) => {
        const row = el('div', 'k');
        row.appendChild(el('span', 'cap', pair[0]));
        row.appendChild(el('span', null, pair[1]));
        k.appendChild(row);
    });
    k.classList.remove('hidden');
}

const held = new Set();
let lastAxes = '0,0,0';

function sendAxes() {
    const a = { turn: 0, tilt: 0, roll: 0 };
    held.forEach((code) => { const m = AXIS_KEYS[code]; if (m) a[m[0]] += m[1]; });
    const key = `${a.turn},${a.tilt},${a.roll}`;
    if (key === lastAxes) return;
    lastAxes = key;
    post('axis', a);
}

function releaseAxes() {
    held.clear();
    sendAxes();
}

window.addEventListener('blur', releaseAxes);

document.addEventListener('keyup', (e) => {
    if (held.delete(e.code)) sendAxes();
});

document.addEventListener('keydown', (e) => {
    if (!S.open || S.naming) return;
    const code = e.code;

    if (AXIS_KEYS[code]) {
        e.preventDefault();
        if (S.view === 'sheet' && S.gun && !S.receipt) { held.add(code); sendAxes(); }
        return;
    }
    // a held Enter or Escape does not repeat
    if (e.repeat && (e.key === 'Enter' || e.key === 'Escape' || e.key === 'Backspace')) { e.preventDefault(); return; }

    if (S.receipt) {
        if (e.key === 'Enter') { e.preventDefault(); work(); }
        else if (e.key === 'Escape' || e.key === 'Backspace') { e.preventDefault(); closeReceipt(); }
        return;
    }
    if (S.working) { e.preventDefault(); return; }

    if (S.view === 'pick') {
        const n = S.guns.length;
        if (e.key === 'ArrowUp' && n) { S.pickFocus = (S.pickFocus - 1 + n) % n; renderPick(); }
        else if (e.key === 'ArrowDown' && n) { S.pickFocus = (S.pickFocus + 1) % n; renderPick(); }
        else if (e.key === 'Enter' && n) pick(S.pickFocus);
        else if (e.key === 'Escape' || e.key === 'Backspace') leave();
        else return;
        e.preventDefault();
        return;
    }

    const tabs = visibleTabs();
    if (e.key === 'ArrowUp') moveFocus(-1);
    else if (e.key === 'ArrowDown') moveFocus(1);
    else if (e.key === 'ArrowLeft') change(-1);
    else if (e.key === 'ArrowRight') change(1);
    else if (e.key === 'Enter') activate();
    else if (e.key === 'Tab') {
        const i = tabs.indexOf(S.tab);
        setTab(tabs[(i + (e.shiftKey ? -1 : 1) + tabs.length) % tabs.length]);
    } else if (/^Digit[1-6]$/.test(code)) {
        const t = tabs[Number(code.slice(5)) - 1];
        if (t) setTab(t);
    } else if (code === 'KeyZ') undoAll();
    else if (code === 'KeyR') post('reset');
    else if (e.key === 'Delete' && S.tab === 'presets' && S.focus > 0) {
        const p = sortedPresets()[S.focus - 1];
        if (p) armDelete(p);
    } else if (e.key === 'Escape' || e.key === 'Backspace') putAway();
    else return;
    e.preventDefault();
});

/* ---------------------------------------------------------------------- mouse on the stage */
const stage = $('stage');
let drag = null;
let dragAcc = { dx: 0, dy: 0 };
let dragTimer = null;

function flushDrag() {
    dragTimer = null;
    if (!dragAcc.dx && !dragAcc.dy) return;
    const d = dragAcc;
    dragAcc = { dx: 0, dy: 0 };
    post('drag', d);
}

stage.addEventListener('mousedown', (e) => {
    if (!S.gun || e.button !== 0) return;
    drag = { x: e.clientX, y: e.clientY };
    stage.classList.add('dragging');
});
window.addEventListener('mousemove', (e) => {
    if (!drag) return;
    dragAcc.dx += e.clientX - drag.x;
    dragAcc.dy += e.clientY - drag.y;
    drag = { x: e.clientX, y: e.clientY };
    if (!dragTimer) dragTimer = setTimeout(flushDrag, 30); // at most every 30 ms
});
window.addEventListener('mouseup', () => {
    if (!drag) return;
    drag = null;
    stage.classList.remove('dragging');
    flushDrag();
});
stage.addEventListener('wheel', (e) => {
    if (!S.gun) return;
    e.preventDefault();
    post('zoom', { notches: e.deltaY > 0 ? 1 : -1 });
}, { passive: false });
stage.addEventListener('dblclick', () => { if (S.gun) post('reset'); });

$('btnUndo').addEventListener('click', undoAll);
$('btnFit').addEventListener('click', openPay);
$('rcNo').addEventListener('click', closeReceipt);
$('rcYes').addEventListener('click', work);

/* ---------------------------------------------------------------------- messages from the game */
function resetState() {
    Object.assign(S, {
        view: 'pick', gun: null, catalogue: {}, fitted: {}, sel: {}, card: null, presets: [],
        tab: 'parts', focus: 0, pickFocus: 0, working: false, picking: false, receipt: false, naming: false,
    });
    if (S.armed) clearTimeout(S.armed.timer);
    S.armed = null;
    held.clear();
    lastAxes = '0,0,0';
    $('receipt').classList.add('hidden');
    $('progress').classList.add('hidden');
    $('root').classList.remove('ongun');
    renderKeys(false);
}

window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.type === 'open') {
        T = d.text || {};
        NAMES = d.names || { weapons: {}, categories: {} };
        CFG = d.cfg || {};
        applyTheme(d.theme);
        resetState();
        S.open = true;
        S.bench = String(d.bench || '');
        S.guns = Array.isArray(d.guns) ? d.guns : [];
        S.wallet = d.wallet || { cash: 0, gold: 0 };
        S.wear = d.wear === true;
        // the player's menu side (fred_hud /hud -> pup-ui): the panel sits there, the key hints opposite
        $('root').classList.toggle('menu-left', d.side === 'left');
        renderPick();
        $('root').classList.remove('hidden');
    } else if (d.type === 'close') {
        S.open = false;
        resetState();
        $('root').classList.add('hidden');
    }
});
