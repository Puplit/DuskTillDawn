/* vorp_character - face & body page.
   Lua (client/facepage.lua) sends: open, close, setPrice, menuSide.
   This page posts: face_set, face_teeth, face_close, face_confirm. */

const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'vorp_character';
function post(name, body) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body || {}),
    }).catch(() => {});
}

let categories = [], items = [];
let currentCategory = null;

const $ = (id) => document.getElementById(id);

function setPct(slider) {
    const min = Number(slider.min), max = Number(slider.max), v = Number(slider.value);
    slider.style.setProperty('--pct', `${((v - min) / Math.max(1, (max - min))) * 100}%`);
}

/* expression sliders run -1.00 .. 1.00; the range input works in -100 .. 100.
   teeth and the Heritage/Build/Age pickers are plain indices, shown as-is. */
/* a pick row may ship `names` (Gender, Clothing) so it reads as a word, not an index */
const disp = (it, raw) => it.kind === 'expr' ? (raw / 100).toFixed(2)
    : ((it.names && it.names[raw - (Number(it.min) || 0)]) || String(raw));

function loadCategories() {
    const box = $('Categories');
    box.innerHTML = '';
    categories.forEach((c, i) => {
        const a = document.createElement('a');
        a.className = 'unselectable';
        a.innerText = c.name;
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
}

function loadItems() {
    const box = $('StyleProperties');
    box.innerHTML = '';
    items.forEach((it) => {
        /* action rows are a button, not a slider - "Remove Hair" and friends */
        if (it.kind === 'action') {
            const arow = document.createElement('div');
            arow.className = 'styleElem action unselectable';
            arow.id = 'item_' + it.id;
            arow.innerHTML = `<p class="elemTitle">${it.name}</p><span class="actionGo">Remove</span>`;
            arow.addEventListener('click', () => post('face_pick', { role: it.role, cat: it.cat }));
            box.appendChild(arow);
            return;
        }

        // expr = a -1..1 face feature; everything else is a discrete index
        const isExpr = it.kind === 'expr';
        const min = isExpr ? -100 : (Number(it.min) || 0);
        const max = isExpr ? 100 : Number(it.max);
        const step = isExpr ? 5 : 1;
        const raw = isExpr ? Math.round(it.value * 100) : Number(it.value);
        const row = document.createElement('div');
        row.className = 'styleElem unselectable' + (isExpr && raw !== 0 ? ' on' : '');
        row.id = 'item_' + it.id;
        row.innerHTML = `
            <p class="elemTitle">${it.name}</p>
            <div class="sliderDiv">
                <p id="val_${it.id}">${disp(it, raw)}</p>
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
            $('val_' + it.id).innerText = disp(it, v);
            if (isExpr) row.classList.toggle('on', v !== 0);
            setPct(slider);
            if (it.kind === 'teeth') {
                it.value = v;
                post('face_teeth', { value: v });
            } else if (it.kind === 'pick') {
                it.value = v;
                post('face_pick', { role: it.role, cat: it.cat, value: v });
            } else {
                it.value = v / 100;
                post('face_set', { comp: it.id, hash: it.hash, value: it.value, tag: it.tag });
            }
        };
        /* Dragging fires `input` continuously but `change` only on release, so a
           drag used to move nothing until you let go - the arrows worked because
           they call send() directly. Send while dragging too, throttled so a fast
           drag cannot flood the NUI callback. Teeth are left on release only:
           each one restarts the dentistry animation. */
        let lastSent = 0, pendingSend = null;
        const THROTTLE_MS = 70;
        const cancelPending = () => { if (pendingSend) { clearTimeout(pendingSend); pendingSend = null; } };
        const liveSend = () => {
            const now = performance.now();
            const wait = THROTTLE_MS - (now - lastSent);
            if (wait <= 0) { cancelPending(); lastSent = now; send(); return; }
            // trailing call so the value you stop on is always the one applied
            if (!pendingSend) {
                pendingSend = setTimeout(() => { pendingSend = null; lastSent = performance.now(); send(); }, wait);
            }
        };

        $('r_' + it.id).addEventListener('click', () => { if (Number(slider.value) < max) { slider.value = Number(slider.value) + step; } cancelPending(); send(); });
        $('l_' + it.id).addEventListener('click', () => { if (Number(slider.value) > min) { slider.value = Number(slider.value) - step; } cancelPending(); send(); });
        /* only expressions stream while dragging: teeth restart an animation and
           the Heritage/Build pickers swap a whole component, both far too heavy
           to fire mid-drag. Those apply on release and on the arrows. */
        slider.addEventListener('input', () => {
            $('val_' + it.id).innerText = disp(it, Number(slider.value));
            setPct(slider);
            if (isExpr) liveSend();
        });
        slider.addEventListener('change', () => { cancelPending(); send(); });
    });
    selectCategory(currentCategory);
}

function openMenu(d) {
    categories = d.categories || [];
    items = d.items || [];
    currentCategory = null;
    $('menuTitle').innerText = (d.title || 'Face & Body').toUpperCase();
    const confirm = $('ConfirmBtn');
    confirm.classList.toggle('hidden', !d.shop);
    if (d.shop) confirm.innerText = 'Confirm - $' + (d.price || 0);
    loadCategories();
    loadItems();
    $('Menu').classList.remove('hidden');
}
function closeMenu() {
    $('Menu').classList.add('hidden');
}

/* Randomise / Reset act on the category you are looking at, never the whole
   face - a dice roll that silently changed a tab you had already finished would
   be worse than useless. Teeth are skipped: they are a component, not an
   expression, and each change restarts the dentistry animation. */
const catExprItems = () => items.filter((it) => it.category === currentCategory && it.kind === 'expr');

/* rows carry -100..100; the ped wants -1..1 */
function applyRaw(pairs) {
    const payload = [];
    pairs.forEach(({ it, raw }) => {
        const slider = $('range_' + it.id);
        if (slider) { slider.value = raw; setPct(slider); }
        const lbl = $('val_' + it.id);
        if (lbl) lbl.innerText = disp(it, raw);
        const row = $('item_' + it.id);
        if (row) row.classList.toggle('on', raw !== 0);
        it.value = raw / 100;
        payload.push({ comp: it.id, hash: it.hash, value: it.value, tag: it.tag });
    });
    if (payload.length) post('face_many', { items: payload });
}

/* average of two uniforms - a triangular roll that favours the middle, so a
   random face looks like a person instead of every slider pinned to an end */
function rollRaw(step) {
    const v = ((Math.random() * 2 - 1) + (Math.random() * 2 - 1)) / 2;
    return Math.round((v * 100) / step) * step;
}

document.addEventListener('DOMContentLoaded', () => {
    $('DoneBtn').addEventListener('click', () => post('face_close'));
    $('ConfirmBtn').addEventListener('click', () => post('face_confirm'));

    document.querySelectorAll('#FaceTools .ft-btn[data-cam]').forEach((b) => {
        b.addEventListener('click', (e) => {
            e.preventDefault();
            document.querySelectorAll('#FaceTools .ft-btn[data-cam]').forEach((o) => o.classList.remove('on'));
            b.classList.add('on');
            post('face_cam', { preset: b.dataset.cam });
        });
    });

    $('ftRandom').addEventListener('click', (e) => {
        e.preventDefault();
        applyRaw(catExprItems().map((it) => ({ it, raw: rollRaw(5) })));
    });
    $('ftReset').addEventListener('click', (e) => {
        e.preventDefault();
        applyRaw(catExprItems().map((it) => ({ it, raw: 0 })));
    });
});

window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.type === 'menuSide') { document.body.classList.toggle('menu-right', d.side === 'right'); return; }
    switch (d.type) {
        case 'open': openMenu(d); break;
        case 'close': closeMenu(); break;
        case 'setPrice': $('ConfirmBtn').innerText = 'Confirm - $' + (d.price || 0); break;
        // a pick changed what other rows can hold (a skin tone with fewer heads),
        // so Lua resends the list; loadItems keeps the open category
        case 'items': items = d.items || []; loadItems(); break;
    }
});

document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && !$('Menu').classList.contains('hidden')) post('face_close');
});

// pup: character codes. Clipboard copy uses the hidden-textarea trick, which is
// what works in CEF - navigator.clipboard is not available here.
window.addEventListener('message', (ev) => {
    const d = ev.data || {};
    if (d.action !== 'pupCopyText' || !d.text) return;
    const box = document.createElement('textarea');
    box.value = String(d.text);
    box.style.position = 'fixed';
    box.style.opacity = '0';
    document.body.appendChild(box);
    box.select();
    try { document.execCommand('copy'); } catch (e) { /* clipboard refused; the code is still on screen */ }
    document.body.removeChild(box);
});