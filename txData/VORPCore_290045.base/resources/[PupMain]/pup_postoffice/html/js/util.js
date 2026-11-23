/* pup_postoffice | page helpers: DOM building, rich-text cleaning, dates, talking to the client */
'use strict';

const U = (() => {
    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'pup_postoffice';

    /** POST to a client NUI callback. Never throws. */
    function post(name, data) {
        return fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => null);
    }

    /**
     * Build an element. Strings among the children become TEXT nodes, so player text is never parsed as HTML.
     * props: class, text, title, type, value, placeholder, maxLength, checked, disabled, attrs{}, data{}, on{event:fn}, style{}
     */
    function h(tag, props, ...kids) {
        const node = document.createElement(tag);
        if (props) {
            for (const k in props) {
                const v = props[k];
                if (v === undefined || v === null || v === false) continue;
                if (k === 'class') node.className = v;
                else if (k === 'text') node.textContent = String(v);
                else if (k === 'on') { for (const ev in v) node.addEventListener(ev, v[ev]); }
                else if (k === 'attrs') { for (const a in v) if (v[a] !== undefined && v[a] !== null) node.setAttribute(a, String(v[a])); }
                else if (k === 'data') { for (const d in v) node.dataset[d] = String(v[d]); }
                else if (k === 'style') { for (const s in v) node.style.setProperty(s, v[s]); }
                else if (k === 'checked' || k === 'disabled' || k === 'value' || k === 'maxLength' || k === 'type' || k === 'placeholder' || k === 'title' || k === 'tabIndex' || k === 'contentEditable' || k === 'spellcheck') node[k] = v;
                else node.setAttribute(k, String(v));
            }
        }
        append(node, kids);
        return node;
    }

    function append(node, kids) {
        for (const kid of kids) {
            if (kid === null || kid === undefined || kid === false) continue;
            if (Array.isArray(kid)) append(node, kid);
            else if (kid instanceof Node) node.appendChild(kid);
            else node.appendChild(document.createTextNode(String(kid)));
        }
    }

    function clear(node) { while (node && node.firstChild) node.removeChild(node.firstChild); return node; }

    /* ---------------------------------------------------------------- icons (our own constant SVG) */
    const ICONS = {
        close: '<path d="M6 6l12 12M18 6L6 18"/>',
        back: '<path d="M15 5l-7 7 7 7"/>',
        pen: '<path d="M4 20l4-1 11-11-3-3L5 16l-1 4z"/><path d="M14 6l3 3"/>',
        inbox: '<path d="M3 13l3-8h12l3 8v6H3z"/><path d="M3 13h5l1 2h6l1-2h5"/>',
        sent: '<path d="M3 11l18-7-7 18-2-8z"/><path d="M12 14l9-10"/>',
        trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
        folder: '<path d="M3 6h6l2 2h10v11H3z"/>',
        plus: '<path d="M12 5v14M5 12h14"/>',
        edit: '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
        book: '<path d="M5 4h11a3 3 0 013 3v13H8a3 3 0 01-3-3z"/><path d="M5 17a3 3 0 013-3h11"/>',
        people: '<circle cx="9" cy="8" r="3"/><circle cx="17" cy="9" r="2.5"/><path d="M3 20c0-4 3-6 6-6s6 2 6 6M15 14c3 0 6 2 6 5"/>',
        gear: '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/>',
        star: '<path d="M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>',
        mask: '<path d="M3 8c3-2 15-2 18 0 0 5-3 9-9 9S3 13 3 8z"/><path d="M7 11h3M14 11h3"/>',
        bell: '<path d="M6 16V11a6 6 0 0112 0v5l2 2H4z"/><path d="M10 20a2 2 0 004 0"/>',
        bellOff: '<path d="M6 16V11a6 6 0 0110-4.5M18 11v5l2 2H8"/><path d="M3 3l18 18"/>',
        check: '<path d="M5 12l5 5 9-10"/>',
        reply: '<path d="M10 7L4 12l6 5"/><path d="M4 12h10a6 6 0 016 6"/>',
        replyAll: '<path d="M8 7L2 12l6 5"/><path d="M13 7l-5 5 5 5"/><path d="M8 12h7a6 6 0 016 6"/>',
        forward: '<path d="M14 7l6 5-6 5"/><path d="M20 12H10a6 6 0 00-6 6"/>',
        move: '<path d="M3 6h6l2 2h10v11H3z"/><path d="M10 13h6M13 10l3 3-3 3"/>',
        restore: '<path d="M4 12a8 8 0 108-8H8"/><path d="M8 1L5 4l3 3"/>',
        search: '<circle cx="11" cy="11" r="6"/><path d="M20 20l-4.5-4.5"/>',
        user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-5 4-7 8-7s8 2 8 7"/>',
        exit: '<path d="M10 4H4v16h6"/><path d="M14 8l4 4-4 4M18 12H9"/>',
        bold: '<path d="M7 4h6a4 4 0 010 8H7zM7 12h7a4 4 0 010 8H7z"/>',
        italic: '<path d="M10 4h8M6 20h8M14 4l-4 16"/>',
        underline: '<path d="M7 4v7a5 5 0 0010 0V4M5 21h14"/>',
        list: '<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r="1"/><circle cx="4.5" cy="12" r="1"/><circle cx="4.5" cy="18" r="1"/>',
        rule: '<path d="M3 12h18"/>',
        send: '<path d="M3 11l18-7-7 18-2-8z"/>',
        chat: '<path d="M4 5h16v11H9l-5 4z"/>',
        pin: '<path d="M9 3h6l-1 6 4 3H6l4-3z"/><path d="M12 12v9"/>',
        info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>',
    };
    const SVGNS = 'http://www.w3.org/2000/svg';
    function icon(name, cls) {
        const svg = document.createElementNS(SVGNS, 'svg');
        svg.setAttribute('viewBox', '0 0 24 24');
        svg.setAttribute('class', 'ico' + (cls ? ' ' + cls : ''));
        svg.setAttribute('aria-hidden', 'true');
        svg.innerHTML = ICONS[name] || '';
        return svg;
    }

    /* ---------------------------------------------------------------- rich text */
    const KEEP = new Set(['B', 'STRONG', 'I', 'EM', 'U', 'S', 'STRIKE', 'DEL', 'BR', 'P', 'DIV', 'SPAN', 'UL', 'OL', 'LI',
        'HR', 'BLOCKQUOTE', 'H1', 'H2', 'H3', 'H4', 'SMALL', 'SUB', 'SUP']);
    const AS_SPAN = new Set(['CENTER', 'FONT']);
    const DROP = new Set(['SCRIPT', 'STYLE', 'IFRAME', 'OBJECT', 'TEMPLATE', 'EMBED', 'NOSCRIPT', 'SVG', 'MATH',
        'TEXTAREA', 'SELECT', 'TITLE', 'HEAD', 'LINK', 'META', 'FRAME', 'FRAMESET', 'APPLET']);
    const MAX_DEPTH = 40;

    function copyClean(from, into, depth) {
        for (const n of Array.from(from.childNodes)) {
            if (n.nodeType === 3) { into.appendChild(document.createTextNode(n.nodeValue)); continue; }
            if (n.nodeType !== 1) continue;
            const tag = String(n.tagName || '').toUpperCase();
            if (DROP.has(tag)) continue;
            if (depth >= MAX_DEPTH) continue;
            let out = null;
            if (KEEP.has(tag)) out = document.createElement(tag === 'STRIKE' ? 'S' : tag);
            else if (AS_SPAN.has(tag)) out = document.createElement('span');
            if (out) {
                into.appendChild(out);
                copyClean(n, out, depth + 1);
            } else {
                copyClean(n, into, depth + 1); // unknown tag: keep its text
            }
        }
    }

    // parsing happens in an inert document: no scripts run and nothing loads
    const parser = new DOMParser();
    function parseInert(raw) {
        return parser.parseFromString('<!doctype html><html><body>' + String(raw || '') + '</body></html>', 'text/html');
    }

    function hasTags(raw) { return /<\s*\/?\s*[a-z!]/i.test(String(raw || '')); }

    function decodeEntities(raw) {
        return parseInert(String(raw || '').replace(/</g, '&lt;')).body.textContent || '';
    }

    /** A safe element holding a letter body. */
    function renderBody(raw) {
        const box = document.createElement('div');
        box.className = 'body-text';
        if (!hasTags(raw)) {
            box.classList.add('plain');
            box.textContent = decodeEntities(raw);
            return box;
        }
        copyClean(parseInert(raw).body, box, 0);
        return box;
    }

    /** Clean HTML text, for sending and for quoting. */
    function cleanHtml(raw) {
        const box = document.createElement('div');
        if (!hasTags(raw)) {
            const text = decodeEntities(raw);
            const lines = text.split(/\r?\n/);
            lines.forEach((line, i) => {
                if (i) box.appendChild(document.createElement('br'));
                box.appendChild(document.createTextNode(line));
            });
            return box.innerHTML;
        }
        copyClean(parseInert(raw).body, box, 0);
        return box.innerHTML;
    }

    function plainText(raw) {
        if (!hasTags(raw)) return decodeEntities(raw);
        const doc = parseInert(String(raw).replace(/<\s*(br|\/p|\/div|\/li|hr)[^>]*>/gi, ' $& '));
        doc.querySelectorAll('script,style,template').forEach(n => n.remove());
        return doc.body.textContent || '';
    }

    function preview(raw, n) {
        const t = plainText(raw).replace(/\s+/g, ' ').trim();
        return t.length > n ? t.slice(0, n - 1) + '…' : t;
    }

    /* ---------------------------------------------------------------- dates */
    const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

    function toDate(iso) {
        const d = new Date(iso);
        return isNaN(d.getTime()) ? null : d;
    }
    function pad(n) { return String(n).padStart(2, '0'); }
    function time(d) { return `${pad(d.getHours())}:${pad(d.getMinutes())}`; }
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
    function ordinal(n) {
        const t = n % 100;
        if (t >= 11 && t <= 13) return n + 'th';
        return n + ({ 1: 'st', 2: 'nd', 3: 'rd' }[n % 10] || 'th');
    }

    function shortDate(iso) {
        const d = toDate(iso); if (!d) return '';
        const now = new Date();
        if (sameDay(d, now)) return time(d);
        const y = new Date(now); y.setDate(now.getDate() - 1);
        if (sameDay(d, y)) return 'Yesterday';
        const week = new Date(now); week.setDate(now.getDate() - 6); week.setHours(0, 0, 0, 0);
        if (d >= week && d <= now) return DAYS[d.getDay()];
        const base = `${d.getDate()} ${MONTHS[d.getMonth()].slice(0, 3)}`;
        return d.getFullYear() === now.getFullYear() ? base : `${base} ${d.getFullYear()}`;
    }
    function fullDate(iso) {
        const d = toDate(iso); if (!d) return '';
        return `${ordinal(d.getDate())} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`;
    }
    function longDate(iso) {
        const d = toDate(iso); if (!d) return '';
        return `${DAYS[d.getDay()]}, ${ordinal(d.getDate())} ${MONTHS[d.getMonth()]} ${d.getFullYear()}, ${time(d)}`;
    }
    function postmark(iso) {
        const d = toDate(iso) || new Date();
        return { day: String(d.getDate()), month: MONTHS[d.getMonth()].slice(0, 3).toUpperCase(), time: time(d) };
    }
    function dayLabel(iso) {
        const d = toDate(iso); if (!d) return '';
        const now = new Date();
        if (sameDay(d, now)) return 'Today';
        const y = new Date(now); y.setDate(now.getDate() - 1);
        if (sameDay(d, y)) return 'Yesterday';
        return `${DAYS[d.getDay()]} ${ordinal(d.getDate())} ${MONTHS[d.getMonth()]}${d.getFullYear() !== now.getFullYear() ? ' ' + d.getFullYear() : ''}`;
    }
    function dayKey(iso) {
        const d = toDate(iso); if (!d) return '';
        return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
    }
    function clock(iso) { const d = toDate(iso); return d ? time(d) : ''; }

    /* ---------------------------------------------------------------- misc */
    const collator = new Intl.Collator(undefined, { numeric: true, sensitivity: 'base' });
    function nameCompare(a, b) {
        const da = /^\d/.test(a || ''), db = /^\d/.test(b || '');
        if (da !== db) return da ? 1 : -1;
        return collator.compare(a || '', b || '');
    }
    function count(n) { return n > 99 ? '99+' : String(n); }
    function initials(name) {
        const parts = String(name || '').replace(/[^\p{L}\p{N}\s]/gu, ' ').trim().split(/\s+/).filter(Boolean);
        if (!parts.length) return '?';
        return (parts[0][0] + (parts.length > 1 ? parts[parts.length - 1][0] : '')).toUpperCase();
    }
    function isBoxNumber(s) { return /^\d{1,10}$/.test(String(s || '').trim()) && Number(String(s).trim()) > 0; }
    function utf8Length(s) { return new TextEncoder().encode(String(s || '')).length; }

    return {
        post, h, clear, icon, renderBody, cleanHtml, plainText, preview, hasTags,
        shortDate, fullDate, longDate, postmark, dayLabel, dayKey, clock,
        nameCompare, count, initials, isBoxNumber, utf8Length,
    };
})();
