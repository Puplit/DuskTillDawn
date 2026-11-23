// pup-pinboard | shared helpers: talking to the game, text, small DOM helpers, toasts, pop-up layers

export const IN_GAME = navigator.userAgent.includes('CitizenFX');
const RESOURCE = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pup-pinboard';

// ---------- the game ----------

// A call that wants an answer names a `reply` message type; client/main.lua sends the answer back as a
// message of that type. A reply that never comes (server restart, dropped event) times out instead of hanging.
const waiting = new Map();
let seq = 0;
let fakeServer = null;

export function useFakeServer(fn) { fakeServer = fn; }

export function post(name, data = {}, onReply = null, timeoutMs = 10000) {
    const body = Object.assign({}, data);
    if (onReply) {
        const type = 'pb_reply_' + (++seq);
        body.reply = type;
        const timer = setTimeout(() => {
            if (!waiting.has(type)) return;
            waiting.delete(type);
            onReply({ ok: false, timedOut: true });
        }, timeoutMs);
        waiting.set(type, (answer) => { clearTimeout(timer); onReply(answer || {}); });
    }
    if (!IN_GAME) {
        if (fakeServer) setTimeout(() => fakeServer(name, body, deliver), 150);
        return;
    }
    fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body),
    }).catch(() => {});
}

// a message from the game: a reply to a call, or something else (show / hide)
export function deliver(message) {
    const type = message && message.type;
    const cb = waiting.get(type);
    if (cb) {
        waiting.delete(type);
        cb(message);
        return true;
    }
    return false;
}

// ---------- text ----------
// The text comes from config/locale.lua. Always placed with textContent, never as HTML.

let texts = {};

export function setTexts(table) { texts = (table && typeof table === 'object') ? table : {}; }

export function L(key, ...args) {
    let s = texts[key];
    if (typeof s !== 'string') s = key;
    let i = 0;
    return s.replace(/%s/g, () => (i < args.length ? String(args[i++]) : ''));
}

// ---------- DOM ----------

export function el(tag, cls, text) {
    const node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
}

export function button(cls, text, onClick) {
    const b = el('button', 'btn' + (cls ? ' ' + cls : ''), text);
    b.type = 'button';
    if (onClick) b.addEventListener('click', onClick);
    return b;
}

// fixed drawings only, never anything a player typed
export const ICONS = {
    prev:   '<svg viewBox="0 0 24 24"><path d="M15.4 4.6 8 12l7.4 7.4-1.8 1.8L4.4 12l9.2-9.2z"/></svg>',
    next:   '<svg viewBox="0 0 24 24"><path d="M8.6 4.6 16 12l-7.4 7.4 1.8 1.8 9.2-9.2-9.2-9.2z"/></svg>',
    left:   '<svg viewBox="0 0 24 24"><path d="M3 5h18v2H3zm0 4h12v2H3zm0 4h18v2H3zm0 4h12v2H3z"/></svg>',
    center: '<svg viewBox="0 0 24 24"><path d="M3 5h18v2H3zm3 4h12v2H6zm-3 4h18v2H3zm3 4h12v2H6z"/></svg>',
    right:  '<svg viewBox="0 0 24 24"><path d="M3 5h18v2H3zm6 4h12v2H9zm-6 4h18v2H3zm6 4h12v2H9z"/></svg>',
};

export function iconButton(cls, icon, title, onClick) {
    const b = button(cls, null, onClick);
    b.innerHTML = ICONS[icon];
    if (title) b.title = title;
    return b;
}

// two or more choices side by side; returns the element and a getter for the lit value
export function segmented(options, value, onChange, small) {
    const box = el('div', 'seg' + (small ? ' seg--small' : ''));
    let current = value;
    const buttons = options.map(([val, label]) => {
        const b = el('button', 'seg__btn' + (val === value ? ' is-on' : ''), label);
        b.type = 'button';
        b.addEventListener('click', () => {
            current = val;
            buttons.forEach((x) => x.classList.toggle('is-on', x === b));
            if (onChange) onChange(val);
        });
        box.appendChild(b);
        return b;
    });
    return { el: box, get: () => current, set: (val) => {
        current = val;
        buttons.forEach((x, i) => x.classList.toggle('is-on', options[i][0] === val));
    } };
}

export function shake(node) {
    node.classList.remove('shake');
    void node.offsetWidth;
    node.classList.add('shake');
}

// ---------- toasts ----------

let toastMs = 4000;
export function setToastDuration(ms) { toastMs = Number(ms) > 0 ? Number(ms) : 4000; }

export function toast(text, isError) {
    const box = document.getElementById('toasts');
    const t = el('div', 'toast' + (isError ? ' toast--error' : ''), text);
    box.appendChild(t);
    setTimeout(() => {
        t.classList.add('is-leaving');
        setTimeout(() => t.remove(), 320);
    }, toastMs);
}

// ---------- pop-up layers ----------
// A stack, so Esc always closes the one on top. A layer can refuse Esc (the writing forms do, so typed text
// is never lost by accident; they have their own Discard button).

const layers = [];

export function openLayer(content, { onEsc = null, escCloses = true, clickOutsideCloses = true } = {}) {
    const overlay = el('div', 'overlay');
    overlay.appendChild(content);
    document.body.appendChild(overlay);
    const layer = {
        overlay,
        close() {
            const i = layers.indexOf(layer);
            if (i !== -1) layers.splice(i, 1);
            overlay.remove();
        },
        esc() {
            if (onEsc) return onEsc();
            if (escCloses) layer.close();
        },
    };
    if (clickOutsideCloses) {
        overlay.addEventListener('mousedown', (e) => { if (e.target === overlay) layer.esc(); });
    }
    layers.push(layer);
    return layer;
}

export function topLayer() { return layers[layers.length - 1] || null; }

export function closeAllLayers() { while (layers.length) layers[layers.length - 1].close(); }

// a yes / no question; resolves true for yes
export function ask(question, yesText, noText, danger) {
    return new Promise((resolve) => {
        const box = el('div', 'ask');
        box.appendChild(el('p', 'ask__text', question));
        const bar = el('div', 'bar');
        let layer;
        const done = (answer) => { layer.close(); resolve(answer); };
        bar.appendChild(button(danger ? 'btn--danger' : 'btn--gold', yesText, () => done(true)));
        bar.appendChild(button('', noText, () => done(false)));
        box.appendChild(bar);
        layer = openLayer(box, { onEsc: () => done(false) });
    });
}
