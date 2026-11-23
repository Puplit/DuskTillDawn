'use strict';
// Reusable pieces: tables, pager, refresh cooldown, form fields, lookups, charge picker,
// person tags, confiscation picker and the # cross-link editor.

// ---------- form fields ----------
function inp(attrs) { return h('input', Object.assign({ class: 'inp', type: 'text' }, attrs || {})); }
function numInp(attrs) { return h('input', Object.assign({ class: 'inp', type: 'number', min: 0, step: 1 }, attrs || {})); }
function area(attrs) { return h('textarea', Object.assign({ class: 'inp', rows: 3 }, attrs || {})); }
// sel([[value,label],...], value)
function sel(options, value, attrs) {
    const s = h('select', Object.assign({ class: 'inp' }, attrs || {}));
    for (const o of options) {
        const opt = h('option', { value: o[0] }, o[1]);
        if (String(o[0]) === String(value)) opt.selected = true;
        s.appendChild(opt);
    }
    return s;
}
function field(label, control, extra) {
    return h('label', { class: 'field' + (extra ? ' ' + extra : '') }, h('span', { class: 'lbl' }, label), control);
}
function row(...kids) { return h('div', { class: 'frow' }, kids); }
function section(title, ...kids) { return h('div', { class: 'fsec' }, h('div', { class: 'fsec-title' }, title), kids); }
function badge(text, tone) { return h('span', { class: 'badge tone-' + (tone || 'grey') }, text); }
function statusDot(on) { return h('span', { class: 'dot ' + (on ? 'on' : 'off') }); }
function emptyState(title, sub, ic) {
    return h('div', { class: 'empty' }, icon(ic || 'inbox'), h('div', { class: 'empty-t' }, title), sub ? h('div', { class: 'empty-s' }, sub) : null);
}
function loading(text) { return h('div', { class: 'empty loading' }, icon('hourglass_top'), h('div', { class: 'empty-t' }, text || T('ui_loading', 'Loading…'))); }

// ---------- tables ----------
// table(cols, rows, { onRow, rowClass, empty, active })
// cols: [{ label, cls, render(row) -> node|string, title(row) }]
function table(cols, rows, o) {
    o = o || {};
    const thead = h('thead', null, h('tr', null, cols.map((c) => h('th', { class: c.cls || '', onclick: c.onSort || null }, c.label, c.sortMark || null))));
    const tbody = h('tbody');
    if (!rows.length) {
        tbody.appendChild(h('tr', { class: 'empty-row' }, h('td', { colspan: cols.length }, o.empty || emptyState(T('ui_nothing_here', 'Nothing here')))));
    }
    for (const r of rows) {
        const tr = h('tr', { class: (o.rowClass ? o.rowClass(r) : '') || '' });
        for (const c of cols) {
            const v = c.render(r);
            const td = h('td', { class: c.cls || '' }, v);
            if (c.title) { const t = c.title(r); if (t) td.title = t; }
            tr.appendChild(td);
        }
        if (o.onRow) {
            tr.classList.add('clickable');
            tr.addEventListener('click', (e) => {
                if (e.target.closest('button, a, input, select, .no-row')) return;
                tbody.querySelectorAll('tr.active').forEach((x) => x.classList.remove('active'));
                tr.classList.add('active');
                o.onRow(r, tr);
            });
        }
        tbody.appendChild(tr);
    }
    return h('div', { class: 'tbl-wrap' }, h('table', { class: 'tbl' }, thead, tbody));
}
function iconBtn(name, title, onclick, cls) {
    return h('button', { class: 'ibtn ' + (cls || ''), type: 'button', title: title || '', onclick: (e) => { e.stopPropagation(); onclick(e); } }, icon(name));
}

// ---------- pager ----------
function pager(page, totalPages, total, go) {
    page = Math.max(1, num(page, 1)); totalPages = Math.max(1, num(totalPages, 1));
    const el = h('div', { class: 'pager' },
        h('button', { class: 'btn ghost sm', type: 'button', disabled: page <= 1, onclick: () => go(page - 1) }, T('ui_prev', '« Prev')),
        h('span', { class: 'pager-t' }, T('ui_page_of', 'Page %d of %d (%d total)', page, totalPages, num(total))),
        h('button', { class: 'btn ghost sm', type: 'button', disabled: page >= totalPages, onclick: () => go(page + 1) }, T('ui_next', 'Next »')));
    if (totalPages <= 1) el.classList.add('hidden');
    return el;
}
// Client-side paging of an array.
function slicePage(list, page, per) {
    const totalPages = Math.max(1, Math.ceil(list.length / per));
    page = Math.min(Math.max(1, page), totalPages);
    return { rows: list.slice((page - 1) * per, page * per), page, totalPages, total: list.length };
}

// ---------- refresh with a 60 s cooldown ----------
const Cooldowns = {};
function refreshBtn(key, fn, cooldown) {
    const ms = cooldown === 0 ? 0 : (cooldown || 60000);
    const label = h('span', null, T('ui_refresh', 'Refresh'));
    const b = h('button', { class: 'btn ghost sm', type: 'button' }, icon('refresh'), label);
    const tick = () => {
        const left = Math.ceil(((Cooldowns[key] || 0) - Date.now()) / 1000);
        if (left > 0) { label.textContent = mmss(left); b.classList.add('cooling'); }
        else { label.textContent = T('ui_refresh', 'Refresh'); b.classList.remove('cooling'); }
        return left;
    };
    b.addEventListener('click', async () => {
        const left = tick();
        if (left > 0) { notify(T('ui_refresh_wait', 'Wait %d s before refreshing again', left), 2500); return; }
        if (ms) Cooldowns[key] = Date.now() + ms;
        label.textContent = T('ui_refreshing', 'refreshing…');
        try { await fn(); } finally { tick(); }
    });
    every(() => { if (b.isConnected) tick(); }, 1000);
    tick();
    return b;
}
function plainRefresh(fn) { return h('button', { class: 'btn ghost sm', type: 'button', onclick: fn }, icon('refresh'), T('ui_refresh', 'Refresh')); }

// ---------- debounced lookup that ignores answers for an older value ----------
// watchLookup(input, delay, ask(value) -> Promise, done(result, value)); also runs on blur.
function watchLookup(input, delay, ask, done) {
    let seq = 0, lastAsked = null;
    const run = async () => {
        const v = input.value.trim();
        if (v === lastAsked) return;
        lastAsked = v;
        const my = ++seq;
        if (!v) { done(null, v, true); return; }
        done(undefined, v); // "looking up"
        const r = await ask(v);
        if (my !== seq || input.value.trim() !== v) return;
        done(r, v);
    };
    const d = debounce(run, delay);
    input.addEventListener('input', () => { lastAsked = null; d(); });
    input.addEventListener('blur', () => { d.cancel(); run(); });
    return { run: () => { lastAsked = null; run(); } };
}
function lookLine() { return h('div', { class: 'lookline' }); }
function setLook(el, text, tone) { el.textContent = text || ''; el.className = 'lookline' + (tone ? ' tone-' + tone : ''); }

// ---------- penal codes (one shared load) ----------
const Penal = { list: null, pending: null, at: 0 };
function loadPenal(force) {
    if (!force && Penal.list && Date.now() - Penal.at < 60000) return Promise.resolve(Penal.list);
    if (Penal.pending) return Penal.pending;
    Penal.pending = nui('getPenalCodes', {}, 8000, null).then((r) => {
        Penal.pending = null;
        if (r === null || r === undefined || typeof r === 'string') return Penal.list || [];
        Penal.list = arr(r).filter((c) => c && c.code).sort((a, b) => naturalCmp(a.code, b.code));
        Penal.at = Date.now();
        return Penal.list;
    });
    return Penal.pending;
}
function classTone(c) { c = str(c).toLowerCase(); return c === 'felony' ? 'red' : c === 'infraction' ? 'green' : 'orange'; }
function classLabel(c) {
    c = str(c).toLowerCase();
    return c === 'felony' ? T('ui_class_felony', 'Felony') : c === 'infraction' ? T('ui_class_infraction', 'Infraction') : T('ui_class_misdemeanor', 'Misdemeanor');
}

// chargePicker(onAdd(code)) -> element. Search box over a dropdown of penal codes.
function chargePicker(onAdd) {
    const q = inp({ placeholder: T('ui_search_charges', 'Search charges by code or name…') });
    const s = h('select', { class: 'inp' });
    let matches = [];
    const label = (c) => T('ui_charge_option', '%s — %s (%d mo / %s)', c.code, c.label, num(c.months), money(c.fine));
    const redraw = () => {
        const list = Penal.list || [];
        const t = q.value.trim().toLowerCase();
        matches = list.filter((c) => !t || str(c.code).toLowerCase().includes(t) || str(c.label).toLowerCase().includes(t));
        clear(s);
        s.appendChild(h('option', { value: '' }, matches.length ? T('ui_n_matches', '— %d matches —', matches.length) : T('ui_no_match', 'no match')));
        matches.forEach((c, i) => s.appendChild(h('option', { value: String(i) }, label(c))));
        if (matches.length === 1 && t) s.selectedIndex = 1;
    };
    q.addEventListener('input', redraw);
    q.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') { e.preventDefault(); if (matches[0]) { onAdd(matches[0]); q.value = ''; redraw(); } }
    });
    s.addEventListener('change', () => {
        const c = matches[num(s.value, -1)];
        if (s.value !== '' && c) { onAdd(c); q.value = ''; redraw(); }
    });
    loadPenal().then(redraw);
    redraw();
    return h('div', { class: 'charge-picker' }, q, s);
}
// Charge tag list with a count stepper. items: [{code,label,charge_class,months,fine,count}]
function chargeTags(items, editable, onChange) {
    const wrap = h('div', { class: 'tags charges' });
    if (!items.length) { wrap.appendChild(h('div', { class: 'muted' }, T('ui_no_charges_selected', 'No charges selected'))); return wrap; }
    items.forEach((c, i) => {
        const n = Math.max(1, num(c.count, 1));
        const pen = (c.months !== undefined || c.fine !== undefined) && (c.months !== null || c.fine !== null)
            ? T('ui_charge_penalty', '%d mo / %s', num(c.months) * n, money(num(c.fine) * n)) : '';
        wrap.appendChild(h('span', { class: 'tag tone-' + classTone(c.charge_class) },
            h('b', null, str(c.code)), ' ', str(c.label),
            editable ? h('span', { class: 'stepper' },
                h('button', { type: 'button', onclick: () => { c.count = Math.max(1, n - 1); onChange(); } }, '−'),
                h('span', null, 'x' + n),
                h('button', { type: 'button', onclick: () => { c.count = Math.min(20, n + 1); onChange(); } }, '+'))
                : (n > 1 ? h('span', { class: 'cnt' }, ' x' + n) : null),
            pen ? h('span', { class: 'pen' }, pen) : null,
            editable ? h('button', { class: 'tag-x', type: 'button', title: T('ui_remove', 'Remove'), onclick: () => { items.splice(i, 1); onChange(); } }, '×') : null));
    });
    return wrap;
}
function addCharge(items, c) {
    const found = items.find((x) => x.code === c.code);
    if (found) found.count = Math.min(20, num(found.count, 1) + 1);
    else items.push({ code: c.code, label: c.label, charge_class: c.charge_class, months: num(c.months), fine: num(c.fine), count: 1 });
}
function chargeTotals(items) {
    let m = 0, f = 0;
    for (const c of items) { const n = Math.max(1, num(c.count, 1)); m += num(c.months) * n; f += num(c.fine) * n; }
    return { months: m, fine: f };
}
function afterDiscount(v, pct) { return Math.floor(num(v) * (1 - Math.min(100, Math.max(0, num(pct))) / 100)); }

// ---------- person tags (involved citizens / lawmen) ----------
// personTags({ list, roles:[[value,label]], idLabel, nameLabel, roleLabel, allowNoName })
function personTags(o) {
    const id = inp({ placeholder: o.idLabel || T('ui_citizen_id', 'Citizen ID') });
    const name = inp({ placeholder: o.nameLabel || T('ui_name', 'Name') });
    const role = sel(o.roles, o.roles[0][0]);
    const tags = h('div', { class: 'tags' });
    const roleText = (v) => { const r = o.roles.find((x) => x[0] === v); return r ? r[1] : v; };
    const redraw = () => {
        clear(tags);
        if (!o.list.length) tags.appendChild(h('span', { class: 'muted' }, T('ui_none_added', 'None added')));
        o.list.forEach((p, i) => tags.appendChild(h('span', { class: 'tag' },
            T('ui_person_tag', '%s (%s) — %s', str(p.name, T('ui_unknown', 'Unknown')), str(p.citizenid), roleText(p[o.roleKey]) || ''),
            h('button', { class: 'tag-x', type: 'button', onclick: () => { o.list.splice(i, 1); redraw(); if (o.onChange) o.onChange(); } }, '×'))));
    };
    const lookup = async (cid) => {
        const r = await nuiPush('lookupCitizen', { citizenid: cid }, 8000, null);
        return (r && r.found) ? str(r.fullname || r.name || ((r.firstname || '') + ' ' + (r.lastname || '')).trim()) : '';
    };
    id.addEventListener('blur', async () => {
        const v = id.value.trim();
        if (!v || name.value.trim()) return;
        const n = await lookup(v);
        if (n && id.value.trim() === v && !name.value.trim()) name.value = n;
    });
    const addBtn = h('button', { class: 'btn sm', type: 'button', onclick: async () => {
        const cid = id.value.trim();
        if (!cid) { notify(T('ui_need_citizen_id', 'Enter a citizen ID first')); return; }
        if (o.list.some((p) => String(p.citizenid) === cid)) { notify(T('ui_already_listed', 'Already listed')); return; }
        let n = name.value.trim();
        if (!n) n = (await lookup(cid)) || T('ui_unknown', 'Unknown');
        const entry = { citizenid: cid, name: n };
        entry[o.roleKey] = role.value;
        o.list.push(entry);
        id.value = ''; name.value = '';
        redraw();
        if (o.onChange) o.onChange();
    } }, icon('add'), T('ui_add', 'Add'));
    redraw();
    const el = h('div', { class: 'person-tags' }, h('div', { class: 'frow tight' }, id, name, role, addBtn), tags);
    el.redraw = redraw;
    return el;
}

// ---------- confiscated items ----------
function itemImg(name) {
    const base = str(App.cfg.inventoryImagePath, 'nui://vorp_inventory/html/img/items/');
    return img(base + str(name).toLowerCase() + '.png', 'item-img', (el) => { el.replaceWith(icon('inventory_2', 'item-img')); });
}
// picker overlay; kind = 'weapon' | 'item'
function openConfiscationPicker(kind, onPick) {
    const src = App.cfg.confiscateds || {};
    const list = arr(kind === 'weapon' ? (src.weapons || src.Weapons) : (src.items || src.Items))
        .map((x) => (typeof x === 'string' ? { name: x, label: x } : { name: str(x.name || x.item), label: str(x.label || x.name) }));
    const q = inp({ placeholder: T('ui_search_items', 'Search…') });
    const grid = h('div', { class: 'item-grid' });
    const redraw = () => {
        const t = q.value.trim().toLowerCase();
        clear(grid);
        const rows = list.filter((x) => !t || x.label.toLowerCase().includes(t) || x.name.toLowerCase().includes(t));
        if (!rows.length) grid.appendChild(emptyState(T('ui_no_match', 'no match')));
        rows.forEach((x) => {
            const tile = h('button', { class: 'item-tile', type: 'button' }, itemImg(x.name), h('span', null, x.label));
            tile.addEventListener('click', () => {
                onPick({ name: x.name, label: x.label, type: kind, quantity: 1 });
                tile.classList.remove('flash'); void tile.offsetWidth; tile.classList.add('flash');
                notify(T('ui_item_added', '%s added', x.label), 1500);
            });
            grid.appendChild(tile);
        });
    };
    q.addEventListener('input', redraw);
    const m = modal({ title: kind === 'weapon' ? T('ui_select_weapons', 'Select Weapons') : T('ui_select_items', 'Select Items'), icon: 'inventory_2', cls: 'wide', body: [q, grid], backdropCloses: true });
    redraw();
    setTimeout(() => q.focus(), 30);
    return m;
}
// confiscation section; list = [{name,label,type,quantity}]
function confiscationBlock(list, onChange) {
    const cards = h('div', { class: 'conf-cards' });
    const redraw = () => {
        clear(cards);
        if (!list.length) { cards.appendChild(h('div', { class: 'muted' }, T('ui_no_confiscated', 'No confiscated items logged'))); return; }
        list.forEach((it, i) => cards.appendChild(h('div', { class: 'conf-card' },
            itemImg(it.name),
            h('div', { class: 'conf-t' }, h('b', null, T('ui_item_count', '%s ×%d', str(it.label, it.name), num(it.quantity, 1))),
                h('small', null, it.type === 'weapon' ? T('ui_weapon', 'Weapon') : T('ui_item', 'Item'))),
            h('span', { class: 'stepper' },
                h('button', { type: 'button', onclick: () => { it.quantity = num(it.quantity, 1) - 1; if (it.quantity <= 0) list.splice(i, 1); redraw(); if (onChange) onChange(); } }, '−'),
                h('span', null, String(num(it.quantity, 1))),
                h('button', { type: 'button', onclick: () => { it.quantity = num(it.quantity, 1) + 1; redraw(); if (onChange) onChange(); } }, '+')),
            h('button', { class: 'tag-x', type: 'button', onclick: () => { list.splice(i, 1); redraw(); if (onChange) onChange(); } }, '×'))));
    };
    const pick = (kind) => openConfiscationPicker(kind, (x) => {
        const f = list.find((y) => y.name === x.name);
        if (f) f.quantity = num(f.quantity, 1) + 1; else list.push(x);
        redraw();
        if (onChange) onChange();
    });
    redraw();
    return h('div', { class: 'conf' },
        h('div', { class: 'frow tight' },
            h('button', { class: 'btn sm', type: 'button', onclick: () => pick('weapon') }, icon('add'), T('ui_add_weapon', 'Add Weapon')),
            h('button', { class: 'btn sm', type: 'button', onclick: () => pick('item') }, icon('add'), T('ui_add_item', 'Add Item'))),
        cards);
}

// ---------- # cross-link editor ----------
const LinkKinds = {
    c: { key: 'cases', kind: 'case', icon: 'folder', word: () => T('ui_link_case', 'case'), tab: 'cases' },
    b: { key: 'bounties', kind: 'bounty', icon: 'balance', word: () => T('ui_link_bounty', 'bounty'), tab: 'bounties' },
    e: { key: 'evidence', kind: 'evidence', icon: 'photo_camera', word: () => T('ui_link_evidence', 'evidence'), tab: 'evidence' },
    r: { key: 'reports', kind: 'report', icon: 'description', word: () => T('ui_link_report', 'report'), tab: 'reports' },
};
const KindByName = { case: 'c', bounty: 'b', evidence: 'e', report: 'r' };
const Linkables = { data: null, pending: null };
function loadLinkables(force) {
    if (!force && Linkables.data) return Promise.resolve(Linkables.data);
    if (Linkables.pending) return Linkables.pending;
    Linkables.pending = nui('getReportLinkables', {}, 8000, null).then((r) => {
        Linkables.pending = null;
        if (r && typeof r === 'object') Linkables.data = { cases: arr(r.cases), bounties: arr(r.bounties), evidence: arr(r.evidence), reports: arr(r.reports) };
        return Linkables.data || { cases: [], bounties: [], evidence: [], reports: [] };
    });
    return Linkables.pending;
}
function safeRef(s) { return str(s).replace(/[^A-Za-z0-9_\-. #]/g, '').slice(0, 40); }
function makeChip(kind, id, ref) {
    const k = LinkKinds[KindByName[kind]];
    if (!k) return document.createTextNode(ref);
    const chip = h('span', { class: 'xchip', contenteditable: 'false', title: T('ui_open_ref', 'Open %s', ref) }, icon(k.icon), ref);
    chip.dataset.kind = kind; chip.dataset.id = String(num(id)); chip.dataset.ref = ref;
    return chip;
}
// Saved format: allow-listed tags with no attributes; chips as text tokens {{#kind|id|ref}}.
const CHIP_RE = /\{\{#(case|bounty|evidence|report)\|(\d+)\|([A-Za-z0-9_\-. #]{1,40})\}\}/g;
function escapeText(s) { return str(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
function serializeRich(root) {
    const out = [];
    const walk = (n) => {
        for (const c of n.childNodes) {
            if (c.nodeType === 3) { out.push(escapeText(c.nodeValue.replace(/\{\{#/g, '{ {#'))); continue; }
            if (c.nodeType !== 1) continue;
            if (c.classList.contains('xchip')) {
                if (Object.prototype.hasOwnProperty.call(KindByName, c.dataset.kind)) out.push('{{#' + c.dataset.kind + '|' + Math.max(0, Math.floor(num(c.dataset.id))) + '|' + safeRef(c.dataset.ref) + '}}');
                else out.push(escapeText(c.textContent));
                continue;
            }
            const tag = c.tagName.toLowerCase();
            if (tag === 'br') { out.push('<br>'); continue; }
            const map = { b: 'b', strong: 'b', i: 'i', em: 'i', u: 'u', p: 'p', div: 'p' };
            const t = map[tag];
            if (t) { out.push('<' + t + '>'); walk(c); out.push('</' + t + '>'); } else walk(c);
        }
    };
    walk(root);
    return out.join('');
}
function plainOfRich(root) {
    const parts = [];
    const walk = (n) => {
        for (const c of n.childNodes) {
            if (c.nodeType === 3) parts.push(c.nodeValue);
            else if (c.nodeType === 1) {
                if (c.classList.contains('xchip')) parts.push(c.dataset.ref);
                else if (c.tagName === 'BR') parts.push('\n');
                else { if (c.tagName === 'P' || c.tagName === 'DIV') parts.push('\n'); walk(c); }
            }
        }
    };
    walk(root);
    return parts.join('').replace(/\n{3,}/g, '\n\n').trim();
}
// Rebuilds saved content into `target` from an inert parse, keeping only the allow-list.
function loadRich(target, saved) {
    clear(target);
    const doc = new DOMParser().parseFromString('<body>' + str(saved) + '</body>', 'text/html');
    const allowed = { B: 'b', STRONG: 'b', I: 'i', EM: 'i', U: 'u', P: 'p', DIV: 'p' };
    const textWithChips = (parent, text) => {
        let last = 0; CHIP_RE.lastIndex = 0; let m;
        while ((m = CHIP_RE.exec(text))) {
            if (m.index > last) parent.appendChild(document.createTextNode(text.slice(last, m.index)));
            parent.appendChild(makeChip(m[1], m[2], m[3]));
            last = m.index + m[0].length;
        }
        if (last < text.length) parent.appendChild(document.createTextNode(text.slice(last)));
    };
    const walk = (src, dst) => {
        for (const c of src.childNodes) {
            if (c.nodeType === 3) { textWithChips(dst, c.nodeValue); continue; }
            if (c.nodeType !== 1) continue;
            if (c.tagName === 'BR') { dst.appendChild(document.createElement('br')); continue; }
            if (c.tagName === 'SCRIPT' || c.tagName === 'STYLE') continue;
            const t = allowed[c.tagName];
            if (t) { const n = document.createElement(t); dst.appendChild(n); walk(c, n); } else walk(c, dst);
        }
    };
    walk(doc.body, target);
}
function openLinkRef(kind, id) {
    const k = LinkKinds[KindByName[kind]];
    if (k) App.showTab(k.tab, { openId: num(id) });
}
// richEditor() -> { el, editor, get(), plain(), set(saved), onDirty }
function richEditor(onDirty) {
    const ed = h('div', { class: 'rich inp', contenteditable: 'true', spellcheck: 'false' });
    const drop = h('div', { class: 'xdrop hidden' });
    let items = [], idx = 0, hashInfo = null;
    const hide = () => { drop.classList.add('hidden'); hashInfo = null; };
    const findHash = () => {
        const s = window.getSelection();
        if (!s.rangeCount || !s.isCollapsed) return null;
        const node = s.anchorNode;
        if (!node || node.nodeType !== 3 || !ed.contains(node)) return null;
        const before = node.nodeValue.slice(0, s.anchorOffset);
        const m = /(^|\s)#([A-Za-z0-9_-]*)$/.exec(before);
        if (!m) return null;
        return { node, start: s.anchorOffset - m[2].length - 1, end: s.anchorOffset, query: m[2] };
    };
    const search = (q) => {
        const d = Linkables.data || { cases: [], bounties: [], evidence: [], reports: [] };
        const lower = q.toLowerCase();
        if (/^[cber]$/.test(lower)) {
            const k = LinkKinds[lower];
            return arr(d[k.key]).slice(0, 8).map((x) => ({ k, x }));
        }
        const lists = Object.values(LinkKinds).map((k) => arr(d[k.key])
            .filter((x) => !lower || str(x.ref).toLowerCase().includes(lower) || str(x.label).toLowerCase().includes(lower))
            .map((x) => ({ k, x })));
        const out = [];
        for (let i = 0; out.length < 8; i++) {
            let any = false;
            for (const l of lists) { if (l[i]) { any = true; out.push(l[i]); if (out.length >= 8) break; } }
            if (!any) break;
        }
        return out;
    };
    const render = () => {
        clear(drop);
        if (!items.length) {
            drop.appendChild(h('div', { class: 'xdrop-none' }, T('ui_link_none', 'No matches — try #c cases · #b bounties · #e evidence · #r reports')));
        }
        items.forEach((it, i) => {
            const r = h('div', { class: 'xdrop-row' + (i === idx ? ' on' : '') }, icon(it.k.icon), h('b', null, str(it.x.ref)), h('span', { class: 'lbl' }, cut(it.x.label, 48)), h('small', null, it.k.word()));
            r.addEventListener('mousedown', (e) => { e.preventDefault(); idx = i; insert(); });
            drop.appendChild(r);
        });
    };
    const place = () => {
        const s = window.getSelection();
        if (!s.rangeCount) return;
        const rect = s.getRangeAt(0).getBoundingClientRect();
        const host = ed.parentNode.getBoundingClientRect();
        drop.style.left = Math.max(0, rect.left - host.left) + 'px';
        drop.style.top = (rect.bottom - host.top + 4) + 'px';
    };
    const update = () => {
        hashInfo = findHash();
        if (!hashInfo) { hide(); return; }
        items = search(hashInfo.query); idx = 0;
        render(); place();
        drop.classList.remove('hidden');
    };
    const insert = () => {
        const it = items[idx];
        if (!it || !hashInfo) { hide(); return; }
        const { node, start, end } = hashInfo;
        const r = document.createRange();
        r.setStart(node, start); r.setEnd(node, Math.min(end, node.nodeValue.length));
        r.deleteContents();
        const chip = makeChip(it.k.kind, it.x.id, safeRef(it.x.ref));
        const space = document.createTextNode(' ');
        r.insertNode(space); r.insertNode(chip);
        const s = window.getSelection();
        const after = document.createRange(); after.setStartAfter(space); after.collapse(true);
        s.removeAllRanges(); s.addRange(after);
        hide();
        if (onDirty) onDirty();
    };
    ed.addEventListener('input', () => { update(); if (onDirty) onDirty(); });
    ed.addEventListener('keydown', (e) => {
        if (drop.classList.contains('hidden')) return;
        if (e.key === 'ArrowDown') { e.preventDefault(); idx = items.length ? (idx + 1) % items.length : 0; render(); }
        else if (e.key === 'ArrowUp') { e.preventDefault(); idx = items.length ? (idx - 1 + items.length) % items.length : 0; render(); }
        else if (e.key === 'Enter' || e.key === 'Tab') { if (items.length) { e.preventDefault(); insert(); } }
        else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); App.escConsumedAt = Date.now(); hide(); }
    });
    ed.addEventListener('blur', () => setTimeout(hide, 150));
    ed.addEventListener('click', (e) => {
        const chip = e.target.closest('.xchip');
        if (chip) openLinkRef(chip.dataset.kind, chip.dataset.id);
    });
    // pasted text only
    ed.addEventListener('paste', (e) => {
        e.preventDefault();
        const t = (e.clipboardData || window.clipboardData).getData('text/plain');
        document.execCommand('insertText', false, t);
    });
    // dropped content would land as live markup: take its text only
    ed.addEventListener('drop', (e) => {
        e.preventDefault();
        const t = e.dataTransfer ? e.dataTransfer.getData('text/plain') : '';
        if (t) { ed.focus(); document.execCommand('insertText', false, t); }
    });
    const el = h('div', { class: 'rich-wrap' }, ed, drop);
    el.isDropOpen = () => !drop.classList.contains('hidden');
    return {
        el, editor: ed,
        get: () => serializeRich(ed),
        plain: () => plainOfRich(ed),
        set: (saved) => { loadRich(ed, saved); hide(); },
    };
}
// Read-only rendering of saved rich content (with clickable chips).
function richView(saved) {
    const d = h('div', { class: 'rich-view' });
    loadRich(d, saved);
    d.addEventListener('click', (e) => { const c = e.target.closest('.xchip'); if (c) openLinkRef(c.dataset.kind, c.dataset.id); });
    return d;
}
function copyText(text) {
    const t = h('textarea', { style: { position: 'fixed', left: '-9999px' } });
    t.value = text; document.body.appendChild(t); t.select();
    try { document.execCommand('copy'); } catch (e) { /* no clipboard */ }
    t.remove();
    notify(T('ui_copied', 'Copied: %s', text), 2000);
}
