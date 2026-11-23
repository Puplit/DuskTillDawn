/* pup-misc / tattoos - mirror menu page.
   Lua (client/tattoos/nui.lua) sends: open, close, items, contextualDatas,
   hidecontextualDatas, setPrice. This page posts: tattoo_item, tattoo_var,
   tattoo_tint, tattoo_save, tattoo_reset, tattoo_body,
   tattoo_cancel. It also answers coordtool's `copy` (same resource, one page). */

const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pup-misc';
function post(name, body) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body || {}),
    }).catch(() => {});
}

/* category icons: white line art in a circle */
const ICONS = {
    tattoos:   '<svg viewBox="0 0 24 24"><path d="M3 21l6.5-6.5M9.5 14.5L18 6l-1.5-1.5-8.5 8.5zM16 4l4 4M14 6l4 4"/><circle cx="19.5" cy="4.5" r="1.4"/></svg>',
    makeup:    '<svg viewBox="0 0 24 24"><path d="M9 14V5.5C9 4 10 3 11.5 3S14 4 14 5.5V14zM8 14h7v7H8z"/><path d="M11.5 3c0-1 .8-1.5 1.5-1"/></svg>',
    lifestyle: '<svg viewBox="0 0 24 24"><circle cx="12" cy="8" r="4.5"/><path d="M4 21c0-4 3.5-7 8-7s8 3 8 7z"/></svg>',
    body:      '<svg viewBox="0 0 24 24"><circle cx="12" cy="4" r="2.5"/><path d="M9 8h6l2 7h-2v6h-2v-5h-2v5H9v-6H7z"/></svg>',
};

let categories = [], items = [], price = 0;
let currentCategory = null, currentItem = null;

const $ = (id) => document.getElementById(id);
const money = (n) => { n = Number(n) || 0; return '$' + (Number.isInteger(n) ? n : n.toFixed(2)); };

function setPct(slider) {
    const min = Number(slider.min) || 0, max = Number(slider.max) || 100, v = Number(slider.value) || 0;
    slider.style.setProperty('--pct', `${((v - min) / Math.max(1, (max - min))) * 100}%`);
}

/* ---------- categories ---------- */
let chipMode = false; /* body adjustments: more groups than circles can fit */
function loadCategories() {
    const box = $('Categories');
    box.innerHTML = '';
    box.classList.toggle('chips', chipMode);
    categories.forEach((c, i) => {
        const a = document.createElement('a');
        if (chipMode) {
            a.className = 'chip unselectable';
            a.innerText = c.name;
        } else {
            a.className = 'categoryElem unselectable';
            a.innerHTML = (ICONS[c.id] || ICONS.lifestyle) + `<span class="catName">${c.name}</span>`;
        }
        a.title = c.name;
        a.addEventListener('click', () => selectCategory(c.id));
        box.appendChild(a);
        if (i === 0 && !currentCategory) currentCategory = c.id;
    });
    selectCategory(currentCategory);
}

function selectCategory(id) {
    currentCategory = id;
    Array.from($('Categories').children).forEach((el, i) => el.classList.toggle('selected', categories[i] && categories[i].id === id));
    items.forEach((it) => {
        const el = $('item_' + it.id);
        if (el) el.classList.toggle('hidden', it.category !== id);
    });
    hideContextual();
    currentItem = null;
}

/* ---------- layer rows ---------- */
/* expression rows (kind 'expr') run -1.00..1.00; the range works in -100..100 */
function loadItems() {
    const box = $('StyleProperties');
    box.innerHTML = '';
    items.forEach((it) => {
        const isExpr = it.kind === 'expr';
        const min = isExpr ? -100 : 0;
        const max = isExpr ? 100 : it.totalAmount;
        const step = isExpr ? 5 : 1;
        const raw = isExpr ? Math.round((it.value || 0) * 100) : it.value;
        const label = (v) => isExpr ? (v / 100).toFixed(2) : `Style ${v}`;
        const row = document.createElement('div');
        row.className = 'styleElem unselectable' + (raw !== 0 ? ' on' : '');
        row.id = 'item_' + it.id;
        row.innerHTML = `
            <p class="elemTitle">${it.name}</p>
            <div class="sliderDiv">
                <p id="val_${it.id}">${label(raw)}</p>
                <div class="sliderElem">
                    <a class="arrow" id="l_${it.id}"><img src="img/arrow.png" alt=""></a>
                    <input type="range" min="${min}" max="${max}" step="${step}" value="${raw}" class="slider" id="range_${it.id}">
                    <a class="arrow right" id="r_${it.id}"><img src="img/arrow.png" alt=""></a>
                </div>
            </div>`;
        box.appendChild(row);
        const slider = $('range_' + it.id);
        setPct(slider);

        const send = () => {
            const v = Number(slider.value);
            it.value = isExpr ? v / 100 : v;
            $('val_' + it.id).innerText = label(v);
            row.classList.toggle('on', v !== 0);
            setPct(slider);
            post('tattoo_item', { category: it.id, item: it.value });
        };
        row.addEventListener('click', () => {
            if (isExpr || currentItem === it.id) return;
            currentItem = it.id;
            document.querySelectorAll('.styleElem').forEach((el) => el.classList.remove('selected'));
            row.classList.add('selected');
            post('tattoo_item', { category: it.id });
        });
        $('r_' + it.id).addEventListener('click', (e) => { e.stopPropagation(); if (Number(slider.value) < max) { slider.value = Number(slider.value) + step; } send(); });
        $('l_' + it.id).addEventListener('click', (e) => { e.stopPropagation(); if (Number(slider.value) > min) { slider.value = Number(slider.value) - step; } send(); });
        slider.addEventListener('input', () => { $('val_' + it.id).innerText = label(Number(slider.value)); setPct(slider); });
        slider.addEventListener('change', send);
        slider.addEventListener('click', (e) => e.stopPropagation());
    });
    selectCategory(currentCategory);
}

function updateItems(list) {
    items = list || [];
    loadItems();
}

/* ---------- contextual (variation / colour) ---------- */
function rangeRow(container, id, label, min, max, value, onChange) {
    const el = document.createElement('div');
    el.className = 'ContextElem unselectable';
    el.innerHTML = `
        <p>${label} - <span id="v_${id}">${value}</span></p>
        <div>
            <a class="arrow" id="l_${id}"><img src="img/arrow.png" alt=""></a>
            <input type="range" class="contRange" id="range_${id}" min="${min}" max="${max}" value="${value}">
            <a class="arrow right" id="r_${id}"><img src="img/arrow.png" alt=""></a>
        </div>`;
    container.appendChild(el);
    const s = $('range_' + id);
    const fire = () => { $('v_' + id).innerText = s.value; onChange(Number(s.value)); };
    $('r_' + id).addEventListener('click', () => { if (Number(s.value) < Number(s.max)) s.value = Number(s.value) + 1; fire(); });
    $('l_' + id).addEventListener('click', () => { if (Number(s.value) > Number(s.min)) s.value = Number(s.value) - 1; fire(); });
    s.addEventListener('input', () => { $('v_' + id).innerText = s.value; });
    s.addEventListener('change', fire);
}

function loadContextual(d) {
    const cat = d.category;
    $('ContextName').innerText = d.name || 'Variation settings';

    const vs = $('varSlider');
    vs.innerHTML = '';
    const hasVar = (Number(d.variationAmount) || 1) > 1;
    vs.classList.toggle('hidden', !hasVar);
    $('separator_var').classList.toggle('hidden', !hasVar);
    if (hasVar) rangeRow(vs, 'variation', 'Var', 0, d.variationAmount, d.variationValue || 0, (v) => post('tattoo_var', { category: cat, item: v }));

    const adv = $('ContextSettingsAdvanced');
    adv.innerHTML = '';
    (d.advancedValues || []).forEach((a) => {
        rangeRow(adv, 'adv_' + a.valueId, a.valueName, a.minValue, a.maxValue, a.valueValue,
            (v) => post('tattoo_var', { category: cat, advancedValue: a.valueName, itemValue: v }));
    });

    const tints = $('TintList');
    tints.innerHTML = '';
    const hasTints = (d.tints || []).length > 0;
    $('separator_colour').classList.toggle('hidden', !hasTints);
    (d.tints || []).forEach((t) => {
        rangeRow(tints, 'tint_' + t.tintId, 'T' + t.tintId, 0, 254, t.value, (v) => post('tattoo_tint', { category: cat, tintId: t.tintId, value: v }));
    });

    $('VariationSettings').classList.remove('hidden');
}
function hideContextual() { $('VariationSettings').classList.add('hidden'); }

/* ---------- camera ---------- */
/* nui.lua drives the camera off A/D, W/S and SHIFT/CTRL; the page only shows the keys */
function loadCamera() {
    $('CamKeys').classList.remove('hidden');
}

/* ---------- open / close ---------- */
function openMenu(d) {
    categories = d.categories || [];
    items = d.items || [];
    price = d.price || 0;
    chipMode = d.chips === true;
    currentCategory = null; currentItem = null;
    $('menuTitle').innerText = (d.title || 'Make Up').toUpperCase();
    $('SaveBtn').innerText = 'Save - ' + money(price);
    $('BodyBtn').innerText = d.bodyLabel || 'Body Adjustments';
    $('BodyBtn').classList.toggle('hidden', d.body === false);
    loadCategories();
    loadItems();
    loadCamera();
    $('Menu').classList.remove('hidden');
}
function closeMenu() {
    $('Menu').classList.add('hidden');
    $('CamKeys').classList.add('hidden');
    hideContextual();
    currentItem = null;
}

/* ---------- coordtool clipboard (shares this page) ---------- */
function copyText(text) {
    const ta = document.createElement('textarea');
    ta.value = text; ta.style.position = 'fixed'; ta.style.left = '-9999px';
    document.body.appendChild(ta); ta.select();
    try { document.execCommand('copy'); } catch (e) {}
    document.body.removeChild(ta);
}

document.addEventListener('DOMContentLoaded', () => {
    $('SaveBtn').addEventListener('click', () => post('tattoo_save'));
    $('ResetBtn').addEventListener('click', () => post('tattoo_reset'));
    $('BodyBtn').addEventListener('click', () => post('tattoo_body'));
    $('CancelBtn').addEventListener('click', () => post('tattoo_cancel'));
});

window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.action === 'copy') { copyText(d.text || ''); return; }
    if (d.type === 'menuSide') { document.body.classList.toggle('menu-right', d.side === 'right'); return; }
    switch (d.type) {
        case 'open': openMenu(d); break;
        case 'close': closeMenu(); break;
        case 'items': updateItems(d.items); break;
        case 'contextualDatas': loadContextual(d.data || {}); break;
        case 'hidecontextualDatas': hideContextual(); break;
        case 'setPrice': price = d.price || 0; $('SaveBtn').innerText = 'Save - ' + money(price); break;
    }
});

document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && !$('Menu').classList.contains('hidden')) post('tattoo_cancel');
});
