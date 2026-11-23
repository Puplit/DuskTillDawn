// pup_clothing | store and wardrobe page. All player and catalogue text goes in through textContent.
'use strict';

const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'pup_clothing';
const $ = (id) => document.getElementById(id);
const SVGNS = 'http://www.w3.org/2000/svg';

function post(name, data) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({}));
}

// ---------------------------------------------------------------------------
// words
// ---------------------------------------------------------------------------
let TEXT = {};
function tr(key, ...args) {
    let s = typeof TEXT[key] === 'string' ? TEXT[key] : key;
    for (const a of args) s = s.replace(/%[sd]/, () => String(a));
    return s;
}

// ---------------------------------------------------------------------------
// theme (pup-ui)
// ---------------------------------------------------------------------------
function toRgb(c) {
    if (typeof c !== 'string') return null;
    const v = c.replace(/\s/g, '');
    let m = v.match(/^#([0-9a-f]{3})$/i);
    if (m) return m[1].split('').map((h) => parseInt(h + h, 16));
    m = v.match(/^#([0-9a-f]{6})([0-9a-f]{2})?$/i);
    if (m) return [0, 2, 4].map((i) => parseInt(m[1].substr(i, 2), 16));
    m = v.match(/^rgba?\((\d+),(\d+),(\d+)/i);
    if (m) return [Number(m[1]), Number(m[2]), Number(m[3])];
    return null;
}
function rgba(c, a) {
    const rgb = toRgb(c);
    return rgb ? `rgba(${rgb[0]}, ${rgb[1]}, ${rgb[2]}, ${a})` : null;
}
const COLOUR_OK = /^(#[0-9a-f]{3,8}|rgba?\([\d\s.,]+\))$/i;
const FONT_OK = /^[\w.-]+\.(ttf|otf)$/i;

function applyTheme(theme) {
    if (!theme || typeof theme !== 'object') return;
    const root = document.documentElement.style;
    const c = theme.colors || {};
    const map = { background: '--bg', text: '--text', textDim: '--dim', accent: '--accent', selected: '--sel', danger: '--danger', good: '--good', border: '--border' };
    for (const [k, v] of Object.entries(map)) {
        if (typeof c[k] === 'string' && COLOUR_OK.test(c[k].trim())) root.setProperty(v, c[k].trim());
    }
    if (c.background) {
        const p = rgba(c.background, 0.92), e = rgba(c.background, 0.7);
        if (p) root.setProperty('--panel', p);
        if (e) root.setProperty('--panel-edge', e);
    }
    if (c.selected) {
        const s = rgba(c.selected, 0.45), s2 = rgba(c.selected, 0.8);
        if (s) root.setProperty('--sel-soft', s);
        if (s2) root.setProperty('--sel-strong', s2);
    }
    const f = theme.fonts || {};
    for (const slot of ['title', 'body']) {
        const file = f[slot];
        if (typeof file === 'string' && FONT_OK.test(file)) {
            const family = `pupc-${slot}`;
            try {
                const face = new FontFace(family, `url("nui://pup-ui/html/fonts/${file}")`);
                face.load().then((loaded) => {
                    document.fonts.add(loaded);
                    root.setProperty(`--font-${slot}`, `'${family}', Georgia, serif`);
                }).catch(() => {});
            } catch (err) { /* keep the system serif */ }
        }
    }
}

function setSide(side) {
    document.body.classList.toggle('menu-right', side === 'right');
}

// ---------------------------------------------------------------------------
// drawn icons (no images)
// ---------------------------------------------------------------------------
// one clean line drawing per group (24x24, drawn with round strokes)
const HAT = [
    ['p', 'M2.5 15.2c1.6 1.9 5.2 2.8 9.5 2.8s7.9-.9 9.5-2.8'],                        // the brim, curled up at the sides
    ['p', 'M6.6 15.6c-.2-3.6.6-7.9 2.4-8.6 1-.4 1.8.7 3 .7s2-1.1 3-.7c1.8.7 2.6 5 2.4 8.6'], // the pinched crown
    ['p', 'M6.7 13.4c3.4.8 7.2.8 10.6 0'],                                              // the band
];
const COAT = [
    ['p', 'M9 3.5L5.6 5.2 3.5 9.5l2.3 1.1L7 9v11.5h10V9l1.2 1.6 2.3-1.1-2.1-4.3L15 3.5'], // body and sleeves
    ['p', 'M9 3.5l3 6.2 3-6.2'],                                                          // the lapels
    ['p', 'M12 9.7v10.8'],                                                                // the opening
    ['c', 13.6, 12.6, 0.55], ['c', 13.6, 15.6, 0.55],                                     // buttons
];
const TROUSERS = [
    ['p', 'M7 3.5h10l1.1 17h-4.2L12 10.2l-1.9 10.3H5.9z'],
    ['p', 'M7.1 6h9.8'],                                                                  // the waistband
    ['p', 'M9 6v1.6M15 6v1.6'],                                                           // belt loops
];
const BOOT = [
    ['p', 'M8 3h6.2v9.6c0 .9.5 1.6 1.4 2l3 1.3c.9.4 1.4 1.2 1.4 2.2v1.6H5v-2.8l3-1.6z'],
    ['p', 'M5 19.7v1.3h3.3v-1.3'],                                                        // the heel
    ['p', 'M8 5.6h6.2'],                                                                  // the pull strap line
    ['p', 'M11 15.2l1.6 1.6'],                                                            // a stitch
];
const GUNBELT = [
    ['p', 'M2.5 8.2c6.2 2.2 12.8 2.2 19 0'], ['p', 'M2.5 11c6.2 2.2 12.8 2.2 19 0'],     // the belt
    ['p', 'M6 9.4v2.6M8.2 9.9v2.6M10.4 10.1v2.6'],                                        // cartridge loops
    ['p', 'M14.6 12.4l.9 8.1h3.4l-.7-8.8'],                                               // the holster
    ['p', 'M15.3 12.3l.5-3.6 2.2.2-.4 3.4'],                                              // the revolver grip
];
const WATCH = [
    ['c', 12, 14, 6.2],
    ['c', 12, 14, 4.6],
    ['p', 'M12 14v-3M12 14l2.1 1.3'],                                                     // the hands
    ['p', 'M12 7.8V6.2M10.6 6.2h2.8'],                                                    // the crown
    ['c', 12, 4.6, 1.2],                                                                  // the bow
];
const ICONS = {
    head: { male: HAT, female: HAT },
    upper: { male: COAT, female: COAT },
    lower: { male: TROUSERS, female: TROUSERS },
    feets: { male: BOOT, female: BOOT },
    weapons: { male: GUNBELT, female: GUNBELT },
    accs: { male: WATCH, female: WATCH },
    eye: [['p', 'M2 12c4-7 16-7 20 0-4 7-16 7-20 0z'], ['c', 12, 12, 3]],
    cross: [['p', 'M6 6l12 12M18 6L6 18']],
};

function svg(shapes, viewBox) {
    const el = document.createElementNS(SVGNS, 'svg');
    el.setAttribute('viewBox', viewBox || '0 0 24 24');
    el.setAttribute('aria-hidden', 'true');
    for (const s of shapes) {
        let node;
        if (s[0] === 'c') {
            node = document.createElementNS(SVGNS, 'circle');
            node.setAttribute('cx', s[1]); node.setAttribute('cy', s[2]); node.setAttribute('r', s[3]);
        } else {
            node = document.createElementNS(SVGNS, 'path');
            node.setAttribute('d', s[1]);
        }
        el.appendChild(node);
    }
    return el;
}

function arrowButton(dir) {
    const b = document.createElement('button');
    b.className = 'arrow';
    b.type = 'button';
    b.appendChild(svg([['p', dir < 0 ? 'M15 5L7 12l8 7z' : 'M9 5l8 7-8 7z']]));
    return b;
}

// a slider with step arrows; onChange(value) fires on every move
function stepper(min, max, value, onChange) {
    const wrap = document.createElement('div');
    wrap.className = 'stepper';
    const left = arrowButton(-1);
    const range = document.createElement('input');
    range.type = 'range';
    range.min = String(min);
    range.max = String(max);
    range.step = '1';
    range.value = String(value);
    const right = arrowButton(1);
    // the track fills red up to the handle
    const fill = () => {
        const lo = Number(range.min), hi = Number(range.max);
        range.style.setProperty('--pct', `${((Number(range.value) - lo) / Math.max(1, hi - lo)) * 100}%`);
    };
    const set = (v) => {
        v = Math.max(min, Math.min(max, Math.round(v)));
        if (String(v) === range.value) return;
        range.value = String(v);
        fill();
        onChange(v);
    };
    left.addEventListener('click', (e) => { e.stopPropagation(); set(Number(range.value) - 1); });
    right.addEventListener('click', (e) => { e.stopPropagation(); set(Number(range.value) + 1); });
    range.addEventListener('input', () => { fill(); onChange(Number(range.value)); });
    wrap.fill = fill;
    fill();
    range.addEventListener('click', (e) => e.stopPropagation());
    wrap.append(left, range, right);
    wrap.range = range;
    return wrap;
}

// send only the newest value per channel, one request in flight at a time
function latestSender(endpoint, onReply) {
    const inflight = {}, pending = {};
    const go = (key) => {
        const payload = pending[key];
        delete pending[key];
        inflight[key] = true;
        post(endpoint, payload).then((r) => {
            inflight[key] = false;
            onReply(r || {}, key);
            if (pending[key]) go(key);
        });
    };
    return (key, payload) => {
        pending[key] = payload;
        if (!inflight[key]) go(key);
    };
}

// ---------------------------------------------------------------------------
// dialogs
// ---------------------------------------------------------------------------
let dialogOpen = null; // 'confirm' | 'name' | null
let onConfirmYes = null;
let onNameDone = null;

function openDialog(kind) {
    dialogOpen = kind;
    $('veil').classList.remove('hidden');
    $('confirm').classList.toggle('hidden', kind !== 'confirm');
    $('nameBox').classList.toggle('hidden', kind !== 'name');
    if (store.open) post('store:dialog', { open: true });
}
function closeDialog() {
    dialogOpen = null;
    onConfirmYes = null;
    onNameDone = null;
    $('veil').classList.add('hidden');
    $('confirm').classList.add('hidden');
    $('nameBox').classList.add('hidden');
    if (store.open) post('store:dialog', { open: false });
}
function confirmBox(text, yes) {
    $('confirmText').textContent = text;
    $('confirmYes').textContent = tr('yes');
    $('confirmNo').textContent = tr('no');
    onConfirmYes = yes;
    openDialog('confirm');
}
function nameBox(maxLen, done) {
    const input = $('nameInput');
    $('nameCreate').textContent = tr('create');
    $('nameCancel').textContent = tr('cancel');
    input.value = '';
    input.maxLength = maxLen;
    input.placeholder = tr('namePlaceholder');
    onNameDone = done;
    openDialog('name');
    setTimeout(() => input.focus(), 0);
}
$('confirmYes').addEventListener('click', () => { const f = onConfirmYes; closeDialog(); if (f) f(); });
$('confirmNo').addEventListener('click', closeDialog);
$('nameCreate').addEventListener('click', () => {
    const f = onNameDone;
    const v = $('nameInput').value.trim();
    closeDialog();
    if (f) f(v === '' ? tr('defaultName') : v);
});
$('nameCancel').addEventListener('click', closeDialog);
$('nameInput').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') { e.preventDefault(); $('nameCreate').click(); }
});

// ---------------------------------------------------------------------------
// store
// ---------------------------------------------------------------------------
const store = {
    open: false, creator: false, tints: false, palettes: 25, channelMax: 254, nameMax: 50,
    sex: 'male', rows: [], groups: [], group: null, selected: null, price: 0,
    rowEls: {}, colourKey: null,
};

function valueText(v, count) {
    return v <= 1 ? tr('none') : tr('style', v - 1, count - 1);
}

function rowByKey(key) { return store.rows.find((r) => r.key === key); }

function updateRowEl(r) {
    const el = store.rowEls[r.key];
    if (!el) return;
    el.classList.toggle('on', r.value > 1);
    el.querySelector('.row-tag').textContent = r.tinted ? tr('tinted') : '';
    el.querySelector('.row-value').textContent = valueText(r.value, r.count);
    if (el.stepperEl.range.value !== String(r.value)) el.stepperEl.range.value = String(r.value);
    el.stepperEl.fill();
}

const sendChange = latestSender('store:change', (reply) => {
    if (!reply || typeof reply.key !== 'string') return;
    const r = rowByKey(reply.key);
    if (!r) return;
    // the slider already shows the newest value; only the dyed mark comes from the client
    r.tinted = reply.tinted === true;
    updateRowEl(r);
    if (store.colourKey === reply.key && r.value <= 1) hideColour();
});

function renderTabs() {
    const tabs = $('tabs');
    tabs.textContent = '';
    for (const g of store.groups) {
        const b = document.createElement('button');
        b.type = 'button';
        b.className = 'tab' + (g.id === store.group ? ' active' : '');
        b.title = g.label;
        const set = ICONS[g.id] || ICONS.accs;
        // a round badge with the drawn icon, the group's name underneath
        const badge = document.createElement('span');
        badge.className = 'tab-badge';
        badge.appendChild(svg(set[store.sex] || set.male));
        const label = document.createElement('span');
        label.className = 'tab-label';
        label.textContent = g.label;
        b.append(badge, label);
        b.addEventListener('click', () => {
            store.group = g.id;
            hideColour();
            renderTabs();
            renderRows();
        });
        tabs.appendChild(b);
    }
}

function renderRows() {
    const box = $('rows');
    box.textContent = '';
    store.rowEls = {};
    for (const r of store.rows) {
        if (r.group !== store.group) continue;
        const el = document.createElement('div');
        el.className = 'row' + (r.key === store.selected ? ' selected' : '');
        const top = document.createElement('div');
        top.className = 'row-top';
        const name = document.createElement('span');
        name.className = 'row-name';
        name.textContent = r.label;
        const tag = document.createElement('span');
        tag.className = 'row-tag';
        top.append(name, tag);
        const value = document.createElement('div');
        value.className = 'row-value';
        const st = stepper(1, r.count, r.value, (v) => {
            r.value = v;
            value.textContent = valueText(v, r.count);
            el.classList.toggle('on', v > 1);
            sendChange(r.key, { key: r.key, value: v });
            if (store.colourKey === r.key && v <= 1) hideColour();
        });
        el.stepperEl = st;
        // the name on the left; the style count above the slider on the right
        const ctl = document.createElement('div');
        ctl.className = 'row-ctl';
        ctl.append(value, st);
        el.append(top, ctl);
        el.addEventListener('click', () => selectRow(r.key));
        box.appendChild(el);
        store.rowEls[r.key] = el;
        updateRowEl(r);
    }
}

function selectRow(key) {
    store.selected = key;
    for (const [k, el] of Object.entries(store.rowEls)) el.classList.toggle('selected', k === key);
    post('store:select', { key }).then((s) => {
        if (store.selected !== key) return;
        if (s && s.show) showColour(s); else hideColour();
    });
}

// colour panel
const sendTint = latestSender('store:tint', (s) => {
    if (s && s.row) {
        const r = rowByKey(s.row.key);
        if (r) { r.tinted = s.row.tinted === true; updateRowEl(r); }
    }
    updatePriceText();
});
const colourState = { palette: 1, c: [0, 0, 0] };

function showColour(s) {
    store.colourKey = s.key;
    colourState.palette = Number(s.palette) || 1;
    colourState.c = Array.isArray(s.c) ? s.c.map((n) => Number(n) || 0) : [0, 0, 0];
    $('colourTitle').textContent = tr('colourTitle', s.label);
    $('colourHint').textContent = tr('colourHint', s.price);
    const box = $('colourSliders');
    box.textContent = '';
    const line = (label, min, max, val, apply) => {
        const wrap = document.createElement('div');
        wrap.className = 'stepper';
        const lab = document.createElement('span');
        lab.className = 'label';
        lab.textContent = label;
        const num = document.createElement('span');
        num.className = 'num';
        num.textContent = String(val);
        const st = stepper(min, max, val, (v) => {
            num.textContent = String(v);
            apply(v);
            sendTint('tint', { key: store.colourKey, palette: colourState.palette, c: colourState.c.slice() });
        });
        wrap.append(lab, st, num);
        box.appendChild(wrap);
    };
    line(tr('palette'), 1, store.palettes, colourState.palette, (v) => { colourState.palette = v; });
    line(tr('tint1'), 0, store.channelMax, colourState.c[0], (v) => { colourState.c[0] = v; });
    line(tr('tint2'), 0, store.channelMax, colourState.c[1], (v) => { colourState.c[1] = v; });
    line(tr('tint3'), 0, store.channelMax, colourState.c[2], (v) => { colourState.c[2] = v; });
    $('colour').classList.remove('hidden');
}
function hideColour() {
    store.colourKey = null;
    $('colour').classList.add('hidden');
}
$('removeColour').addEventListener('click', () => {
    const key = store.colourKey;
    if (!key) return;
    post('store:removeTint', { key }).then((r) => {
        const row = r && rowByKey(r.key);
        if (row) { row.tinted = false; updateRowEl(row); }
        hideColour();
    });
});

// the camera guide: key caps and what they do (locale page.controls); falls back to the one-line hint
function renderControls() {
    const box = $('keyHint');
    box.textContent = '';
    const list = Array.isArray(TEXT.controls) ? TEXT.controls : null;
    box.classList.toggle('guide', !!list);
    if (!list) { box.textContent = tr('keyHint'); return; }
    const title = document.createElement('div');
    title.className = 'guide-title';
    title.textContent = tr('controlsTitle');
    box.appendChild(title);
    const grid = document.createElement('div');
    grid.className = 'guide-grid';
    for (const c of list) {
        if (!c || !Array.isArray(c.keys)) continue;
        const item = document.createElement('div');
        item.className = 'guide-item';
        const caps = document.createElement('span');
        caps.className = 'caps';
        for (const k of c.keys) {
            const cap = document.createElement('kbd');
            cap.textContent = String(k);
            caps.appendChild(cap);
        }
        const what = document.createElement('span');
        what.className = 'what';
        what.textContent = String(c.label || '');
        item.append(caps, what);
        grid.appendChild(item);
    }
    box.appendChild(grid);
}

// "Save" with the price as its own gold figure (the game font has no dash glyph)
function updatePriceText() {
    const b = $('btnSave');
    b.textContent = '';
    if (store.creator) { b.textContent = tr('done'); return; }
    const word = document.createElement('span');
    word.textContent = tr('save');
    const price = document.createElement('span');
    price.className = 'price';
    price.textContent = `$${store.price}`;
    b.append(word, price);
}

function openStore(d) {
    store.open = true;
    store.creator = d.creator === true;
    store.tints = d.tints === true;
    store.palettes = Number(d.palettes) || 25;
    store.channelMax = Number(d.channelMax) || 254;
    store.nameMax = Number(d.nameMax) || 50;
    store.sex = d.sex === 'female' ? 'female' : 'male';
    store.price = Number(d.price) || 0;
    store.rows = Array.isArray(d.rows) ? d.rows : [];
    store.groups = Array.isArray(d.groups) ? d.groups : [];
    store.group = store.groups.length ? store.groups[0].id : null;
    store.selected = null;
    if (d.side) setSide(d.side);
    $('storeTitle').textContent = String(d.title || '');
    $('btnReset').textContent = tr('reset');
    $('btnSaveAs').textContent = tr('saveAs');
    $('btnCancel').textContent = tr('cancel');
    $('btnSaveAs').classList.toggle('hidden', store.creator);
    renderControls();
    $('removeColour').textContent = tr('removeColour');
    updatePriceText();
    hideColour();
    renderTabs();
    renderRows();
    $('wardrobe').classList.add('hidden');
    $('store').classList.remove('hidden');
    $('keyHint').classList.remove('hidden');
}

function closeStore() {
    store.open = false;
    closeDialog();
    hideColour();
    $('store').classList.add('hidden');
    $('keyHint').classList.add('hidden');
}

$('btnSave').addEventListener('click', () => post('store:save', {}));
$('btnSaveAs').addEventListener('click', () => {
    nameBox(store.nameMax, (name) => post('store:save', { name }));
});
$('btnReset').addEventListener('click', () => {
    confirmBox(tr('resetAsk'), () => {
        post('store:reset', {}).then((r) => {
            if (r && Array.isArray(r.rows)) store.rows = r.rows;
            if (r && typeof r.price === 'number') store.price = r.price;
            updatePriceText();
            hideColour();
            renderRows();
        });
    });
});
$('btnCancel').addEventListener('click', () => post('store:cancel', {}));

// ---------------------------------------------------------------------------
// wardrobe
// ---------------------------------------------------------------------------
const wardrobe = { open: false, list: [] };

function renderOutfits() {
    const box = $('outfits');
    box.textContent = '';
    const q = $('search').value.trim().toLowerCase();
    let shown = 0;
    for (const o of wardrobe.list) {
        const title = String(o.title || '');
        if (q && !title.toLowerCase().includes(q)) continue;
        shown++;
        const row = document.createElement('div');
        row.className = 'outfit';
        const name = document.createElement('span');
        name.className = 'outfit-name';
        name.textContent = title;
        const wear = document.createElement('button');
        wear.type = 'button';
        wear.className = 'icon-btn';
        wear.title = tr('wear');
        wear.appendChild(svg(ICONS.eye));
        wear.addEventListener('click', () => post('wardrobe:wear', { id: o.id }));
        const del = document.createElement('button');
        del.type = 'button';
        del.className = 'icon-btn danger';
        del.title = tr('delete');
        del.appendChild(svg(ICONS.cross));
        del.addEventListener('click', () => {
            confirmBox(tr('deleteAsk', title), () => post('wardrobe:delete', { id: o.id }));
        });
        row.append(name, wear, del);
        box.appendChild(row);
    }
    $('noOutfits').textContent = tr('noOutfits');
    $('noOutfits').classList.toggle('hidden', shown > 0);
}

function openWardrobe(list) {
    wardrobe.open = true;
    wardrobe.list = Array.isArray(list) ? list : [];
    $('wardrobeTitle').textContent = tr('outfits');
    $('search').placeholder = tr('search');
    $('search').value = '';
    $('btnClose').textContent = tr('close');
    renderOutfits();
    $('store').classList.add('hidden');
    $('keyHint').classList.add('hidden');
    $('wardrobe').classList.remove('hidden');
}

function closeWardrobe() {
    wardrobe.open = false;
    closeDialog();
    $('wardrobe').classList.add('hidden');
}

$('search').addEventListener('input', renderOutfits);
$('btnClose').addEventListener('click', () => post('wardrobe:close', {}));

// ---------------------------------------------------------------------------
// keys and messages
// ---------------------------------------------------------------------------
// the camera keys (Space, Shift, arrows) must never press or move a focused control
document.addEventListener('mouseup', () => {
    const a = document.activeElement;
    if (a && (a.tagName === 'BUTTON' || (a.tagName === 'INPUT' && a.type === 'range'))) a.blur();
});
document.addEventListener('keydown', (e) => {
    const tgt = e.target;
    if (tgt && (tgt.tagName === 'BUTTON' || (tgt.tagName === 'INPUT' && tgt.type === 'range')) && e.key !== 'Escape') {
        e.preventDefault();
        return;
    }
    if (e.key !== 'Escape') return;
    e.preventDefault();
    if (dialogOpen) { closeDialog(); return; }
    if (store.open) post('store:cancel', {});
    else if (wardrobe.open) post('wardrobe:close', {});
});

window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    // the open messages carry the words too, in case the 'ready' answer was missed
    if (d.text && typeof d.text === 'object') TEXT = d.text;
    switch (d.action) {
        case 'openStore': openStore(d); break;
        case 'closeStore': closeStore(); break;
        case 'price':
            store.price = Number(d.price) || 0;
            updatePriceText();
            break;
        case 'openWardrobe': openWardrobe(d.outfits); break;
        case 'outfits':
            wardrobe.list = Array.isArray(d.outfits) ? d.outfits : [];
            if (wardrobe.open) renderOutfits();
            break;
        case 'closeWardrobe': closeWardrobe(); break;
        case 'menuSide': setSide(d.side); break;
        default: break;
    }
});

// the page can load before the client script has registered 'ready'; ask again a few times
function askReady(tries) {
    post('ready', {}).then((r) => {
        if (!r || !r.text) {
            if (tries > 0) setTimeout(() => askReady(tries - 1), 2000);
            return;
        }
        if (typeof r.text === 'object') TEXT = r.text;
        applyTheme(r.theme);
        if (r.side) setSide(r.side);
    });
}
askReady(10);
