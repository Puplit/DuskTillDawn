'use strict';
// Core helpers shared by every page: DOM builder, text, NUI calls, formatting, layers.

const App = window.App = {
    tabs: {}, built: {}, order: [],
    player: null, settings: {}, cfg: {},
    open: false, lawyer: false, current: null, history: [],
    waiters: {}, ridSeq: 0,
};
const RES = (typeof window.GetParentResourceName === 'function') ? window.GetParentResourceName() : 'pup-mdt';

// ---------- DOM ----------
// h(tag, attrs, ...children). Strings and numbers become text nodes; nothing is parsed as markup.
function h(tag, attrs, ...kids) {
    const el = document.createElement(tag);
    if (attrs) {
        for (const k in attrs) {
            const v = attrs[k];
            if (v === undefined || v === null || v === false) continue;
            if (k === 'class') el.className = v;
            else if (k === 'style' && typeof v === 'object') Object.assign(el.style, v);
            else if (k === 'dataset') Object.assign(el.dataset, v);
            else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
            else if (k === 'value') el.value = v;
            else if (k === 'checked' || k === 'disabled' || k === 'selected' || k === 'readOnly') el[k] = !!v;
            else if (k === 'text') el.textContent = String(v);
            else el.setAttribute(k, v === true ? '' : String(v));
        }
    }
    add(el, kids);
    return el;
}
function add(el, kids) {
    for (const k of kids) {
        if (k === null || k === undefined || k === false) continue;
        if (Array.isArray(k)) add(el, k);
        else if (k instanceof Node) el.appendChild(k);
        else el.appendChild(document.createTextNode(String(k)));
    }
    return el;
}
function clear(el) { while (el && el.firstChild) el.removeChild(el.firstChild); return el; }
function fill(el, ...kids) { clear(el); return add(el, kids); }
function $(sel, root) { return (root || document).querySelector(sel); }
function icon(name, cls) { return h('span', { class: 'mi' + (cls ? ' ' + cls : ''), 'aria-hidden': 'true' }, name); }
function show(el, on) { if (el) el.classList.toggle('hidden', !on); }

// ---------- text ----------
const I18N = { strings: {} };
// T(key, english, ...args): locale text, falling back to the built-in English; %s/%d are filled in order.
function T(key, def, ...args) {
    let s = I18N.strings[key];
    if (typeof s !== 'string' || s === '') s = (def !== undefined && def !== null) ? def : key;
    let i = 0;
    return s.replace(/%[sd]/g, () => { const v = args[i++]; return v === undefined || v === null ? '' : String(v); });
}
function plural(n, one, many) { return n === 1 ? one : many; }

// ---------- NUI ----------
// Posts a callback. Resolves with the parsed reply, or `fallback` when nothing came back.
async function nui(name, data, timeout, fallback) {
    const ms = (timeout || 8000) + 1500;
    const ctrl = (typeof AbortController !== 'undefined') ? new AbortController() : null;
    const timer = ctrl ? setTimeout(() => ctrl.abort(), ms) : null;
    try {
        const r = await fetch('https://' + RES + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
            signal: ctrl ? ctrl.signal : undefined,
        });
        const txt = await r.text();
        if (timer) clearTimeout(timer);
        if (txt === '') return fallback === undefined ? null : fallback;
        try { return JSON.parse(txt); } catch (e) { return txt; }
    } catch (e) {
        if (timer) clearTimeout(timer);
        return fallback === undefined ? null : fallback;
    }
}
// For callbacks whose data arrives as a pushed message: the client copies `_rid` into that message.
function nuiPush(name, data, timeout, fallback) {
    const rid = 'r' + (++App.ridSeq) + '_' + Date.now();
    return new Promise((resolve) => {
        const t = setTimeout(() => { delete App.waiters[rid]; resolve(fallback === undefined ? null : fallback); }, (timeout || 8000) + 1500);
        App.waiters[rid] = (msg) => { clearTimeout(t); delete App.waiters[rid]; resolve(msg); };
        nui(name, Object.assign({}, data || {}, { _rid: rid }), timeout, 'ok');
    });
}
function resolveWaiter(msg) {
    if (msg && msg._rid && App.waiters[msg._rid]) { App.waiters[msg._rid](msg); return true; }
    return false;
}
function notify(message, duration) {
    if (!message) return;
    nui('mdtNotify', { message: String(message), duration: duration || 4000 });
}
// Arrays sometimes arrive as Lua tables with holes or as {} when empty.
function arr(v) {
    if (Array.isArray(v)) return v;
    if (v && typeof v === 'object') {
        const keys = Object.keys(v);
        if (!keys.every((k) => /^\d+$/.test(k))) return [];
        return keys.sort((a, b) => a - b).map((k) => v[k]);
    }
    return [];
}
function num(v, d) { const n = Number(v); return isFinite(n) ? n : (d || 0); }
function str(v, d) { return (v === undefined || v === null || v === '') ? (d === undefined ? '' : d) : String(v); }
function ok(r) { return !!(r && (r.success === true || r.ok === true)); }
function msgOf(r, def) { return (r && typeof r.message === 'string' && r.message) ? r.message : def; }

// ---------- formatting ----------
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
function toDate(v) {
    if (v === undefined || v === null || v === '') return null;
    if (v instanceof Date) return v;
    if (typeof v === 'number' || /^\d+$/.test(String(v))) {
        let n = Number(v);
        if (n < 1e12) n *= 1000;
        const d = new Date(n);
        return isNaN(d) ? null : d;
    }
    const d = new Date(String(v).replace(' ', 'T'));
    return isNaN(d) ? null : d;
}
function pad(n) { return n < 10 ? '0' + n : '' + n; }
function fmtDate(v, dash) {
    const d = toDate(v);
    if (!d) return dash === undefined ? '—' : dash;
    return MONTHS[d.getMonth()] + ' ' + pad(d.getDate()) + ', ' + d.getFullYear();
}
function fmtTime(v) { const d = toDate(v); return d ? pad(d.getHours()) + ':' + pad(d.getMinutes()) : ''; }
function fmtDateTime(v) { const d = toDate(v); return d ? fmtDate(d) + ' ' + fmtTime(d) : '—'; }
function isoDay(v) { const d = toDate(v); return d ? d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) : ''; }
function relTime(v) {
    const d = toDate(v);
    if (!d) return '';
    const s = Math.max(0, (Date.now() - d.getTime()) / 1000);
    if (s < 120) return T('ui_time_just_now', 'just now');
    if (s < 3600) return T('ui_time_minutes_ago', '%d minutes ago', Math.floor(s / 60));
    if (s < 86400) { const n = Math.floor(s / 3600); return n === 1 ? T('ui_time_hour_ago', '1 hour ago') : T('ui_time_hours_ago', '%d hours ago', n); }
    const n = Math.floor(s / 86400);
    return n === 1 ? T('ui_time_day_ago', '1 day ago') : T('ui_time_days_ago', '%d days ago', n);
}
function money(v) { return '$' + Math.floor(num(v)).toLocaleString('en-US'); }
function mmss(sec) { sec = Math.max(0, Math.floor(sec)); return Math.floor(sec / 60) + ':' + pad(sec % 60); }
function cut(s, n) { s = str(s); return s.length > n ? s.slice(0, n - 1) + '…' : s; }
function isHttpUrl(u) { return /^https?:\/\/[^\s"'<>]+$/i.test(str(u).trim()); }

// ---------- permissions and switches ----------
function can(p) { return !!(App.player && App.player.permissions && App.player.permissions[p] === true); }
function featureOn(key) {
    if (!key) return true;
    const v = App.settings ? App.settings[key] : undefined;
    return !(v === false || v === 0 || v === '0' || v === 'false');
}

// ---------- timing ----------
function debounce(fn, ms) {
    let t = null;
    const f = function (...a) { clearTimeout(t); t = setTimeout(() => fn.apply(this, a), ms); };
    f.cancel = () => clearTimeout(t);
    return f;
}
const Timers = new Set();
function every(fn, ms) { const id = setInterval(fn, ms); Timers.add(id); return id; }
function stopTimers() { Timers.forEach((id) => clearInterval(id)); Timers.clear(); }

// ---------- layers (modals, panels, overlays) ----------
// Every modal registers here so ESC/Backspace close the topmost one with its own close action.
const Layers = [];
function pushLayer(el, close) {
    const z = 1000 + Layers.length * 10;
    if (el && el.style) el.style.zIndex = String(z);
    Layers.push({ el, close });
}
function popLayer(el) {
    const i = Layers.findIndex((l) => l.el === el);
    if (i >= 0) Layers.splice(i, 1);
}
function closeTopLayer() {
    for (let i = Layers.length - 1; i >= 0; i--) {
        const l = Layers[i];
        if (!l.el || !l.el.isConnected) { Layers.splice(i, 1); continue; }
        // on a tab that is not showing (or hidden itself): leave it registered, look further down
        if (l.el.getClientRects().length === 0) continue;
        l.close();
        return true;
    }
    return false;
}
function closeAllLayers() {
    while (Layers.length) { const l = Layers.pop(); try { l.close(true); } catch (e) { /* already gone */ } }
}

// modal({ title, icon, cls, body, footer, onClose, backdropCloses, parent })
function modal(o) {
    const box = h('div', { class: 'modal page-turn ' + (o.cls || '') });
    const close = (silent) => {
        if (!back.isConnected) return;
        popLayer(back);
        back.remove();
        if (o.onClose && !silent) o.onClose();
    };
    const head = h('div', { class: 'modal-head' },
        o.icon ? icon(o.icon) : null,
        h('h3', null, o.title || ''),
        o.headExtra || null,
        h('button', { class: 'x', type: 'button', title: T('ui_close', 'Close'), onclick: () => close() }, icon('close')));
    const body = h('div', { class: 'modal-body' }, o.body || null);
    const foot = o.footer ? h('div', { class: 'modal-foot' }, o.footer) : null;
    add(box, [o.noHead ? null : head, body, foot]);
    const back = h('div', { class: 'backdrop' }, box);
    if (o.backdropCloses) back.addEventListener('mousedown', (e) => { if (e.target === back) close(); });
    (o.parent || $('#overlays')).appendChild(back);
    pushLayer(back, () => close());
    return { el: back, box, body, foot, close, head };
}

// confirmBox({ title, message, confirm, danger, reason }) -> Promise<false | true | {reason}>
function confirmBox(o) {
    return new Promise((resolve) => {
        let done = false;
        const reason = o.reason ? h('textarea', { class: 'inp', rows: 3, placeholder: o.reasonPlaceholder || T('ui_reason_optional', 'Reason (optional)') }) : null;
        const finish = (v) => { if (done) return; done = true; m.close(true); resolve(v); };
        const m = modal({
            title: o.title || T('ui_confirm', 'Confirm'), icon: 'warning', cls: 'confirm',
            body: [h('p', { class: 'confirm-msg' }, o.message || ''), reason],
            footer: [
                h('button', { class: 'btn ghost', type: 'button', onclick: () => finish(false) }, T('ui_cancel', 'Cancel')),
                h('button', { class: 'btn ' + (o.danger ? 'danger' : 'primary'), type: 'button', onclick: () => finish(reason ? { reason: reason.value.trim() } : true) }, o.confirm || T('ui_confirm', 'Confirm')),
            ],
            onClose: () => { if (!done) { done = true; resolve(false); } },
        });
        // × answers "no" through onClose; ESC uses the same close
    });
}

// Disables a button while `fn` runs, showing `busyText`.
async function busy(btn, busyText, fn) {
    if (!btn || btn.disabled) return;
    const old = btn.textContent;
    btn.disabled = true;
    if (busyText) btn.textContent = busyText;
    try { return await fn(); } finally {
        if (btn.isConnected || true) { btn.disabled = false; btn.textContent = old; }
    }
}

// Natural number sort for codes like "P.C. 1001".
function naturalCmp(a, b) { return String(a).localeCompare(String(b), undefined, { numeric: true, sensitivity: 'base' }); }

// Image with a fallback: on error it hides itself (or calls onFail).
function img(src, cls, onFail) {
    const el = h('img', { class: cls || '', alt: '', referrerpolicy: 'no-referrer' });
    el.addEventListener('error', () => { if (onFail) onFail(el); else el.classList.add('hidden'); });
    if (src && (isHttpUrl(src) || /^nui:\/\//i.test(src) || /^img\//.test(src))) el.src = src; else el.classList.add('hidden');
    return el;
}

window.addEventListener('error', (e) => { if (App.cfg && App.cfg.nuiDebug) console.log('[pup-mdt] ' + e.message); });
